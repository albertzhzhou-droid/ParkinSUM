import { mkdirSync, writeFileSync, renameSync, lstatSync, realpathSync } from 'node:fs';
import { dirname, resolve, relative, isAbsolute } from 'node:path';

// The existing CLI stdout remains unchanged. Only this declared local producer
// directory can receive a machine report; arbitrary/private paths are refused.
export function emitContractReport(report, args = process.argv.slice(2), cwd = process.cwd()) {
  if (args.some((arg) => !arg.startsWith('--report=')) || args.length > 1) throw new Error('Unsupported contract report argument');
  if (args.length) {
    const path = args[0].slice('--report='.length);
    if (isAbsolute(path) || !/^build\/verify_all\/producers\/[a-z0-9_]+\.json$/.test(path)) throw new Error('Report path is outside the producer allowlist');
    const target = resolve(cwd, path);
    mkdirSync(dirname(target), { recursive: true });
    if (relative(realpathSync(cwd), realpathSync(dirname(target))).startsWith('..')) throw new Error('Report parent escapes the checkout');
    try { if (lstatSync(target).isSymbolicLink()) throw new Error('Report symlinks are refused'); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    const temporary = `${target}.${process.pid}.tmp`;
    writeFileSync(temporary, `${JSON.stringify(report, null, 2)}\n`, { flag: 'wx' });
    renameSync(temporary, target);
  }
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}
