const androidNamespaceUri = 'http://schemas.android.com/apk/res/android';

export const postNotificationsPermission =
  'android.permission.POST_NOTIFICATIONS';
export const scheduledNotificationBootReceiver =
  'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver';
export const bootCompletedAction = 'android.intent.action.BOOT_COMPLETED';

function parseQualifiedName(name, namespaces) {
  const colon = name.lastIndexOf(':');
  if (colon < 0) {
    return { namespaceUri: null, localName: name };
  }

  const qualifier = name.slice(0, colon);
  const localName = name.slice(colon + 1);
  if (!qualifier || !localName) {
    throw new Error(`Malformed qualified XML name: ${name}`);
  }
  return {
    namespaceUri:
      qualifier === androidNamespaceUri
        ? androidNamespaceUri
        : (namespaces.get(qualifier) ?? `unresolved:${qualifier}`),
    localName,
  };
}

function parseJsonString(token, context) {
  try {
    const parsed = JSON.parse(token);
    if (typeof parsed !== 'string') throw new Error('not a string');
    return parsed;
  } catch {
    throw new Error(`${context} contains an invalid quoted value`);
  }
}

function parseAttributeValue(valueText, context) {
  let encodedValue = valueText.trim();
  let rawValue = null;
  const rawMatch = /\s+\(Raw:\s*("(?:\\.|[^"\\])*")\)\s*$/.exec(
    encodedValue,
  );
  if (rawMatch) {
    rawValue = parseJsonString(rawMatch[1], `${context} Raw value`);
    encodedValue = encodedValue.slice(0, rawMatch.index).trim();
  }

  let value;
  let valueKind;
  if (/^"(?:\\.|[^"\\])*"$/.test(encodedValue)) {
    value = parseJsonString(encodedValue, context);
    valueKind = 'quoted';
  } else if (encodedValue === 'true' || encodedValue === 'false') {
    value = encodedValue === 'true';
    valueKind = 'boolean';
  } else if (/^\(type 0x12\)0x[01]$/.test(encodedValue)) {
    value = encodedValue.endsWith('1');
    valueKind = 'boolean';
  } else if (encodedValue.length > 0 && !/[\r\n]/.test(encodedValue)) {
    value = encodedValue;
    valueKind = 'encoded';
  } else {
    throw new Error(`${context} has no parseable value`);
  }

  if (rawValue != null && valueKind === 'quoted' && rawValue !== value) {
    throw new Error(`${context} decoded and Raw values disagree`);
  }

  return { encodedValue, rawValue, value, valueKind };
}

function parseNamespace(body, lineNumber, namespaces) {
  const withoutLocation = body.replace(/\s+\(line=\d+\)\s*$/, '').trim();
  const equals = withoutLocation.indexOf('=');
  if (equals <= 0 || equals === withoutLocation.length - 1) {
    throw new Error(`Malformed namespace record at output line ${lineNumber}`);
  }
  const prefix = withoutLocation.slice(0, equals).trim();
  const uri = withoutLocation.slice(equals + 1).trim();
  if (!/^[A-Za-z_][A-Za-z0-9_.-]*$/.test(prefix) || !uri) {
    throw new Error(`Malformed namespace record at output line ${lineNumber}`);
  }
  if (namespaces.has(prefix)) {
    throw new Error(`Duplicate namespace prefix ${prefix}`);
  }
  namespaces.set(prefix, uri);
}

function parseElement(body, indent, lineNumber, namespaces) {
  const match = /^([^\s()]+)(?:\s+\(line=\d+\))?$/.exec(body.trim());
  if (!match) {
    throw new Error(`Malformed element record at output line ${lineNumber}`);
  }
  const qualifiedName = match[1];
  const { namespaceUri, localName } = parseQualifiedName(
    qualifiedName,
    namespaces,
  );
  return {
    qualifiedName,
    namespaceUri,
    localName,
    indent,
    outputLine: lineNumber,
    attributes: [],
    children: [],
  };
}

function parseAttribute(body, indent, lineNumber, namespaces) {
  const equals = body.indexOf('=');
  if (equals <= 0 || equals === body.length - 1) {
    throw new Error(`Malformed attribute record at output line ${lineNumber}`);
  }
  const qualifiedName = body
    .slice(0, equals)
    .trim()
    .replace(/\(0x[0-9a-f]+\)$/i, '');
  if (!qualifiedName || /\s/.test(qualifiedName)) {
    throw new Error(`Malformed attribute name at output line ${lineNumber}`);
  }
  const { namespaceUri, localName } = parseQualifiedName(
    qualifiedName,
    namespaces,
  );
  return {
    qualifiedName,
    namespaceUri,
    localName,
    indent,
    outputLine: lineNumber,
    ...parseAttributeValue(
      body.slice(equals + 1),
      `Attribute ${qualifiedName} at output line ${lineNumber}`,
    ),
  };
}

/**
 * Parses the indentation tree emitted by:
 *   aapt2 dump xmltree --file AndroidManifest.xml <apk>
 *
 * Namespace and comment/text records are not interpreted as XML elements, so
 * strings inside comments cannot satisfy a manifest assertion.
 */
export function parseAapt2XmlTree(output) {
  if (typeof output !== 'string' || output.trim().length === 0) {
    throw new Error('aapt2 XML tree output is empty');
  }

  const namespaces = new Map();
  const roots = [];
  const stack = [];
  const lines = output.split(/\r?\n/);

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.trim().length === 0) continue;
    const leading = /^[ \t]*/.exec(line)?.[0] ?? '';
    if (leading.includes('\t')) {
      throw new Error(`Tabs make indentation ambiguous at output line ${index + 1}`);
    }
    const record = /^([A-Z]):\s*(.*)$/.exec(line.slice(leading.length));
    if (!record) continue;

    const [, kind, body] = record;
    const indent = leading.length;
    if (kind === 'N') {
      if (roots.length > 0) {
        throw new Error('Namespace declaration appears after the XML tree root');
      }
      parseNamespace(body, index + 1, namespaces);
      continue;
    }
    if (kind !== 'E' && kind !== 'A') {
      continue;
    }

    while (stack.length > 0 && stack.at(-1).indent >= indent) {
      stack.pop();
    }

    if (kind === 'E') {
      const element = parseElement(body, indent, index + 1, namespaces);
      const parent = stack.at(-1);
      if (parent) {
        parent.children.push(element);
      } else {
        roots.push(element);
      }
      stack.push(element);
      continue;
    }

    const parent = stack.at(-1);
    if (!parent || indent <= parent.indent) {
      throw new Error(`Attribute has no unambiguous parent at output line ${index + 1}`);
    }
    if (parent.children.length > 0) {
      throw new Error(
        `Attribute appears after child elements at output line ${index + 1}`,
      );
    }
    const attribute = parseAttribute(body, indent, index + 1, namespaces);
    if (
      parent.attributes.some(
        (candidate) =>
          candidate.namespaceUri === attribute.namespaceUri &&
          candidate.localName === attribute.localName,
      )
    ) {
      throw new Error(
        `Duplicate attribute ${attribute.qualifiedName} on ${parent.qualifiedName}`,
      );
    }
    parent.attributes.push(attribute);
  }

  return { namespaces, roots };
}

function descendants(node, localName) {
  const matches = [];
  const visit = (candidate) => {
    for (const child of candidate.children) {
      if (child.localName === localName) matches.push(child);
      visit(child);
    }
  };
  visit(node);
  return matches;
}

function requireSingleElement(elements, description) {
  if (elements.length !== 1) {
    throw new Error(`${description} must occur exactly once; found ${elements.length}`);
  }
  return elements[0];
}

function requireAndroidAttribute(element, localName) {
  const candidates = element.attributes.filter(
    (attribute) => attribute.localName === localName,
  );
  if (candidates.length !== 1) {
    throw new Error(
      `${element.localName} android:${localName} must occur exactly once; found ${candidates.length}`,
    );
  }
  if (candidates[0].namespaceUri !== androidNamespaceUri) {
    throw new Error(`${element.localName} ${localName} is not Android-namespaced`);
  }
  return candidates[0];
}

function requireUnqualifiedAttribute(element, localName) {
  const candidates = element.attributes.filter(
    (attribute) => attribute.localName === localName,
  );
  if (candidates.length !== 1) {
    throw new Error(
      `${element.localName} ${localName} must occur exactly once; found ${candidates.length}`,
    );
  }
  if (candidates[0].namespaceUri != null) {
    throw new Error(`${element.localName} ${localName} must be unqualified`);
  }
  return candidates[0];
}

function requireQuotedString(attribute, description) {
  if (
    attribute.valueKind !== 'quoted' ||
    typeof attribute.value !== 'string' ||
    attribute.value.trim().length === 0
  ) {
    throw new Error(`${description} must be a non-empty resolved string`);
  }
  return attribute.value;
}

function requireBoolean(attribute, expected, description) {
  if (attribute.valueKind !== 'boolean' || attribute.value !== expected) {
    throw new Error(`${description} must be ${expected}`);
  }
  return attribute.value;
}

function assertExpectedOptions(options) {
  if (options == null || typeof options !== 'object' || Array.isArray(options)) {
    throw new Error('Manifest inspection options must be an object');
  }
  const allowed = new Set(['expectedPackageName', 'expectedApplicationLabel']);
  const unknown = Object.keys(options).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw new Error(`Unknown manifest inspection option: ${unknown.join(', ')}`);
  }
}

export function inspectAndroidApkManifestTree(parsed, options = {}) {
  assertExpectedOptions(options);
  if (
    parsed == null ||
    !(parsed.namespaces instanceof Map) ||
    !Array.isArray(parsed.roots)
  ) {
    throw new Error('Parsed aapt2 XML tree has an invalid shape');
  }
  if (parsed.namespaces.get('android') !== androidNamespaceUri) {
    throw new Error('Android namespace declaration is missing or invalid');
  }

  const manifest = requireSingleElement(
    parsed.roots.filter(
      (element) =>
        element.localName === 'manifest' && element.namespaceUri == null,
    ),
    'manifest root',
  );
  if (parsed.roots.length !== 1) {
    throw new Error(`XML tree must have exactly one root; found ${parsed.roots.length}`);
  }

  const packageName = requireQuotedString(
    requireUnqualifiedAttribute(manifest, 'package'),
    'manifest package',
  );
  if (!/^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+$/.test(packageName)) {
    throw new Error('manifest package is not a valid qualified package name');
  }

  const applications = descendants(manifest, 'application');
  const application = requireSingleElement(applications, 'application element');
  if (!manifest.children.includes(application) || application.namespaceUri != null) {
    throw new Error('application must be an unqualified direct child of manifest');
  }
  const applicationLabel = requireQuotedString(
    requireAndroidAttribute(application, 'label'),
    'application label',
  );

  const postNotificationDeclarations = descendants(
    manifest,
    'uses-permission',
  ).filter((permission) => {
    const nameAttributes = permission.attributes.filter(
      (attribute) => attribute.localName === 'name',
    );
    return (
      nameAttributes.length === 1 &&
      nameAttributes[0].namespaceUri === androidNamespaceUri &&
      nameAttributes[0].valueKind === 'quoted' &&
      nameAttributes[0].value === postNotificationsPermission
    );
  });
  const postNotificationDeclaration = requireSingleElement(
    postNotificationDeclarations,
    postNotificationsPermission,
  );
  if (
    !manifest.children.includes(postNotificationDeclaration) ||
    postNotificationDeclaration.namespaceUri != null
  ) {
    throw new Error(`${postNotificationsPermission} must be declared on manifest`);
  }

  const bootReceivers = descendants(application, 'receiver').filter(
    (receiver) => {
      const nameAttributes = receiver.attributes.filter(
        (attribute) => attribute.localName === 'name',
      );
      return (
        nameAttributes.length === 1 &&
        nameAttributes[0].namespaceUri === androidNamespaceUri &&
        nameAttributes[0].valueKind === 'quoted' &&
        nameAttributes[0].value === scheduledNotificationBootReceiver
      );
    },
  );
  const bootReceiver = requireSingleElement(
    bootReceivers,
    scheduledNotificationBootReceiver,
  );
  if (!application.children.includes(bootReceiver) || bootReceiver.namespaceUri != null) {
    throw new Error('Scheduled notification boot receiver must be a direct application child');
  }
  requireBoolean(
    requireAndroidAttribute(bootReceiver, 'exported'),
    false,
    'Scheduled notification boot receiver android:exported',
  );

  const bootActions = descendants(bootReceiver, 'action').filter((action) => {
    const nameAttributes = action.attributes.filter(
      (attribute) => attribute.localName === 'name',
    );
    return (
      nameAttributes.length === 1 &&
      nameAttributes[0].namespaceUri === androidNamespaceUri &&
      nameAttributes[0].valueKind === 'quoted' &&
      nameAttributes[0].value === bootCompletedAction
    );
  });
  const bootAction = requireSingleElement(bootActions, bootCompletedAction);
  const bootIntentFilters = bootReceiver.children.filter(
    (child) => child.localName === 'intent-filter' && child.namespaceUri == null,
  );
  const owningFilters = bootIntentFilters.filter((filter) =>
    filter.children.includes(bootAction),
  );
  if (owningFilters.length !== 1 || bootAction.namespaceUri != null) {
    throw new Error(
      `${bootCompletedAction} must be a direct action of one boot receiver intent-filter`,
    );
  }

  if (
    options.expectedPackageName != null &&
    options.expectedPackageName !== packageName
  ) {
    throw new Error(
      `manifest package mismatch: expected ${options.expectedPackageName}, found ${packageName}`,
    );
  }
  if (
    options.expectedApplicationLabel != null &&
    options.expectedApplicationLabel !== applicationLabel
  ) {
    throw new Error(
      `application label mismatch: expected ${options.expectedApplicationLabel}, found ${applicationLabel}`,
    );
  }

  return {
    packageName,
    applicationLabel,
    postNotificationsDeclared: true,
    bootReceiver: {
      className: scheduledNotificationBootReceiver,
      exported: false,
      bootCompletedActionDeclared: true,
    },
  };
}

export function inspectAndroidApkManifest(output, options = {}) {
  return inspectAndroidApkManifestTree(parseAapt2XmlTree(output), options);
}
