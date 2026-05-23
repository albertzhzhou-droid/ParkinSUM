/// Localized message overlays for [baselineCdssRules].
///
/// Schema: `ruleId → localeTag → translated text`. The mapping is merged into
/// each rule's `messages.localized` block at composition time inside
/// `baseline_cdss_rules.dart`, so the rule source file stays readable while
/// translations live in one auditable spot.
///
/// Locales covered (matches `LocaleResourceSeedImporter` and the `AppI18n`
/// runtime override path):
///   ko-KR · hi-IN · es-ES · es-MX · vi-VN · th-TH · id-ID · ru-RU · pl-PL · ar-SA
///
/// Existing `zh` (required) and `en` (optional) fields on each rule are
/// untouched. Locales that do not appear here continue to fall back through
/// `RuleMessageSet.forLocale`'s usual chain (exact tag → family → en → zh).
const Map<String, Map<String, String>> kBaselineCdssRuleTranslations = {
  'pd.ldopa.protein.window.v1': {
    'ko-KR': '고단백 식사는 레보도파의 흡수나 임상 반응을 감소시킬 수 있으므로 시간을 분리하는 것이 권장됩니다.',
    'hi-IN':
        'उच्च प्रोटीन भोजन लेवोडोपा अवशोषण या नैदानिक प्रतिक्रिया को कम कर सकता है; समय अलग करने की सिफारिश की जाती है।',
    'es':
        'Las comidas ricas en proteínas pueden reducir la absorción de la levodopa o la respuesta clínica; se recomienda separar los horarios.',
    'es-MX':
        'Las comidas altas en proteína pueden reducir la absorción de la levodopa o la respuesta clínica; se recomienda separar los horarios.',
    'vi-VN':
        'Bữa ăn giàu đạm có thể làm giảm hấp thu levodopa hoặc đáp ứng lâm sàng; nên uống thuốc cách xa bữa ăn.',
    'th-TH':
        'อาหารโปรตีนสูงอาจลดการดูดซึมเลโวโดปาหรือการตอบสนองทางคลินิก แนะนำให้แยกเวลารับประทาน',
    'id-ID':
        'Makanan tinggi protein dapat mengurangi penyerapan levodopa atau respons klinis; disarankan menjarakkan waktu.',
    'ru-RU':
        'Пища с высоким содержанием белка может снижать всасывание леводопы или клинический ответ; рекомендуется разнесение во времени.',
    'pl-PL':
        'Posiłki bogate w białko mogą zmniejszać wchłanianie lewodopy lub odpowiedź kliniczną; zaleca się rozdzielenie pór.',
    'ar-SA':
        'قد تقلل الوجبات الغنية بالبروتين من امتصاص الليفودوبا أو الاستجابة السريرية؛ يُوصى بالفصل بين أوقات تناول الدواء والوجبات.',
  },
  'pd.ldopa.iron.v1': {
    'ko-KR':
        '철염이나 철분 함유 종합비타민은 레보도파/카비도파와 킬레이트화되어 생체이용률을 감소시킬 수 있으므로 분리해서 복용하세요.',
    'hi-IN':
        'आयरन लवण या आयरन युक्त मल्टीविटामिन लेवोडोपा/कार्बिडोपा से चिलेट बना सकते हैं और जैवउपलब्धता घटा सकते हैं; अलग-अलग समय पर लें।',
    'es':
        'Las sales de hierro o multivitamínicos con hierro pueden formar quelatos con la levodopa/carbidopa y reducir su biodisponibilidad; tómelos por separado.',
    'es-MX':
        'Las sales de hierro o multivitamínicos con hierro pueden formar quelatos con la levodopa/carbidopa y reducir su biodisponibilidad; tómelos por separado.',
    'vi-VN':
        'Muối sắt hoặc đa sinh tố có sắt có thể tạo phức với levodopa/carbidopa và giảm sinh khả dụng; nên uống cách xa nhau.',
    'th-TH':
        'เกลือเหล็กหรือวิตามินรวมที่มีธาตุเหล็กอาจจับกับเลโวโดปา/คาร์บิโดปาและลดชีวประสิทธิผล แนะนำให้รับประทานแยกเวลา',
    'id-ID':
        'Garam besi atau multivitamin yang mengandung besi dapat membentuk kelat dengan levodopa/karbidopa dan menurunkan bioavailabilitas; minum terpisah.',
    'ru-RU':
        'Соли железа или поливитамины с железом могут образовывать хелаты с леводопой/карбидопой и снижать биодоступность; принимайте раздельно.',
    'pl-PL':
        'Sole żelaza lub multiwitaminy z żelazem mogą chelatować lewodopę/karbidopę i obniżać biodostępność; przyjmuj je osobno.',
    'ar-SA':
        'قد ترتبط أملاح الحديد أو الفيتامينات المتعددة المحتوية على الحديد بالليفودوبا/كاربيدوبا وتقلل التوافر الحيوي؛ يُنصح بالفصل بين الجرعات.',
  },
  'pd.rasagiline.tyramine.us.v1': {
    'ko-KR':
        '권장 용량의 rasagiline에서는 일반적으로 티라민 제한이 필요하지 않지만, 극도로 높은 티라민 섭취는 심각한 혈압 상승을 유발할 수 있습니다.',
    'hi-IN':
        'अनुशंसित खुराक पर rasagiline के साथ आमतौर पर सामान्य टायरामाइन प्रतिबंध आवश्यक नहीं है, परन्तु अत्यधिक टायरामाइन सेवन गंभीर रक्तचाप वृद्धि कर सकता है।',
    'es':
        'A las dosis recomendadas, rasagiline normalmente no requiere restricción general de tiramina, pero ingestas muy elevadas pueden provocar reacciones hipertensivas graves.',
    'es-MX':
        'A las dosis recomendadas, la rasagilina normalmente no requiere restricción general de tiramina, pero un consumo muy alto puede provocar reacciones hipertensivas graves.',
    'vi-VN':
        'Với liều khuyến cáo, rasagiline thường không cần kiêng tyramine, nhưng lượng tyramine rất cao có thể gây phản ứng tăng huyết áp nghiêm trọng.',
    'th-TH':
        'ที่ขนาดยาแนะนำ rasagiline มักไม่จำเป็นต้องจำกัดไทรามีนทั่วไป แต่การบริโภคไทรามีนสูงมากอาจทำให้เกิดความดันโลหิตสูงรุนแรง',
    'id-ID':
        'Pada dosis yang direkomendasikan, rasagiline umumnya tidak memerlukan pembatasan tiramin, tetapi asupan tiramin yang sangat tinggi dapat memicu reaksi hipertensi berat.',
    'ru-RU':
        'В рекомендуемых дозах rasagiline обычно не требует общего ограничения тирамина, но очень высокое потребление может вызвать тяжёлую гипертензивную реакцию.',
    'pl-PL':
        'W zalecanych dawkach rasagilina zwykle nie wymaga ogólnego ograniczenia tyraminy, ale bardzo wysokie spożycie może wywołać ciężką reakcję nadciśnieniową.',
    'ar-SA':
        'في الجرعات الموصى بها، لا يتطلب الراساجيلين عادةً تقييدًا عامًا للتيرامين، لكن تناول كميات مرتفعة جدًا قد يسبب ارتفاعًا حادًا في ضغط الدم.',
  },
  'pd.safinamide.tyramine.us.v1': {
    'ko-KR':
        '권장 용량의 safinamide에서는 일반적으로 티라민 제한이 필요하지 않지만, 극도로 높은 티라민 섭취는 피해야 합니다.',
    'hi-IN':
        'अनुशंसित खुराक पर safinamide के साथ आमतौर पर नियमित टायरामाइन प्रतिबंध आवश्यक नहीं है, परन्तु अत्यधिक टायरामाइन सेवन से बचना चाहिए।',
    'es':
        'A las dosis recomendadas, safinamide normalmente no requiere restricción habitual de tiramina, pero deben evitarse ingestas muy elevadas.',
    'es-MX':
        'A las dosis recomendadas, la safinamida normalmente no requiere restricción habitual de tiramina, pero deben evitarse ingestas muy altas.',
    'vi-VN':
        'Với liều khuyến cáo, safinamide thường không cần kiêng tyramine thường quy, nhưng vẫn nên tránh lượng tyramine rất cao.',
    'th-TH':
        'ที่ขนาดยาแนะนำ safinamide มักไม่จำเป็นต้องจำกัดไทรามีนตามปกติ แต่ควรหลีกเลี่ยงการบริโภคไทรามีนสูงมาก',
    'id-ID':
        'Pada dosis yang direkomendasikan, safinamide umumnya tidak memerlukan pembatasan tiramin rutin, tetapi asupan tiramin yang sangat tinggi tetap harus dihindari.',
    'ru-RU':
        'В рекомендуемых дозах safinamide обычно не требует рутинного ограничения тирамина, но очень высокого потребления следует избегать.',
    'pl-PL':
        'W zalecanych dawkach safinamid zwykle nie wymaga rutynowego ograniczenia tyraminy, ale należy unikać bardzo wysokiego spożycia.',
    'ar-SA':
        'في الجرعات الموصى بها، لا يتطلب السافيناميد عادةً تقييدًا روتينيًا للتيرامين، لكن يجب تجنب الكميات المرتفعة جدًا.',
  },
  'pd.peg.starch_thickener.block.v1': {
    'ko-KR':
        'PEG 제제와 전분 기반 증점제를 혼합하면 점도가 감소하고 흡인 위험이 증가할 수 있으므로 함께 섞어서는 안 됩니다.',
    'hi-IN':
        'PEG उत्पादों को स्टार्च-आधारित गाढ़ा करने वाले के साथ मिलाने से चिपचिपाहट घट सकती है और आकांक्षा (aspiration) का जोखिम बढ़ सकता है; इन्हें मिलाएँ नहीं।',
    'es':
        'Mezclar productos con PEG y espesantes a base de almidón puede reducir la viscosidad y aumentar el riesgo de aspiración; no deben combinarse.',
    'es-MX':
        'Mezclar productos con PEG y espesantes a base de almidón puede reducir la viscosidad y aumentar el riesgo de broncoaspiración; no deben combinarse.',
    'vi-VN':
        'Trộn chế phẩm chứa PEG với chất làm đặc gốc tinh bột có thể làm giảm độ nhớt và tăng nguy cơ hít sặc; không được trộn lẫn.',
    'th-TH':
        'การผสมผลิตภัณฑ์ PEG กับสารเพิ่มความข้นชนิดแป้งอาจทำให้ความหนืดลดลงและเพิ่มความเสี่ยงต่อการสำลัก ห้ามผสมกัน',
    'id-ID':
        'Mencampur produk PEG dengan pengental berbasis pati dapat menurunkan viskositas dan meningkatkan risiko aspirasi; jangan dicampur.',
    'ru-RU':
        'Смешивание препаратов PEG с загустителями на основе крахмала может снижать вязкость и повышать риск аспирации; смешивать нельзя.',
    'pl-PL':
        'Mieszanie preparatów PEG z zagęstnikami skrobiowymi może zmniejszać lepkość i zwiększać ryzyko aspiracji; nie należy ich łączyć.',
    'ar-SA':
        'قد يؤدي مزج مستحضرات PEG مع المثخّنات النشوية إلى انخفاض اللزوجة وزيادة خطر الشفط؛ لا ينبغي خلطها.',
  },
  'pd.ldopa.enteral.feed.review.v1': {
    'ko-KR':
        '지속적 경장영양은 레보도파 반응을 방해할 수 있습니다. 약사와 영양 팀이 단백질 양과 영양 공급 시간 창을 기준으로 평가해야 합니다.',
    'hi-IN':
        'निरंतर एंटरल पोषण लेवोडोपा प्रतिक्रिया में हस्तक्षेप कर सकता है; प्रोटीन मात्रा और फीडिंग विंडो के अनुसार फार्मासिस्ट और पोषण टीम द्वारा मूल्यांकन कराएँ।',
    'es':
        'La nutrición enteral continua puede interferir con la respuesta a la levodopa; el farmacéutico y el equipo de nutrición deben evaluarla según la cantidad de proteína y la ventana de alimentación.',
    'es-MX':
        'La nutrición enteral continua puede interferir con la respuesta a la levodopa; el farmacéutico y el equipo de nutrición deben evaluarla según la cantidad de proteína y la ventana de alimentación.',
    'vi-VN':
        'Nuôi dưỡng qua đường ruột liên tục có thể can thiệp vào đáp ứng với levodopa; cần dược sĩ và nhóm dinh dưỡng đánh giá theo lượng đạm và khung giờ cho ăn.',
    'th-TH':
        'การให้สารอาหารทางลำไส้แบบต่อเนื่องอาจรบกวนการตอบสนองต่อเลโวโดปา ควรให้ทีมเภสัชกรและโภชนาการประเมินตามปริมาณโปรตีนและช่วงเวลาให้อาหาร',
    'id-ID':
        'Nutrisi enteral kontinu dapat mengganggu respons levodopa; apoteker dan tim gizi harus mengevaluasinya berdasarkan jumlah protein dan jendela pemberian.',
    'ru-RU':
        'Непрерывное энтеральное питание может нарушать ответ на леводопу; фармацевт и нутрициологическая команда должны оценить ситуацию с учётом количества белка и режима кормления.',
    'pl-PL':
        'Ciągłe żywienie dojelitowe może zakłócać odpowiedź na lewodopę; farmaceuta i zespół żywieniowy powinni ocenić ilość białka i okno karmienia.',
    'ar-SA':
        'قد تتعارض التغذية المعوية المستمرة مع استجابة الليفودوبا؛ يجب أن يقيّمها الصيدلي وفريق التغذية بناءً على كمية البروتين ونافذة التغذية.',
  },
  'pd.pramipexole.food.info.v1': {
    'ko-KR':
        '프라미펙솔은 식사와 함께 또는 공복에 복용할 수 있으며, 메스꺼움이 있는 경우 식사와 함께 복용하면 완화에 도움이 될 수 있습니다.',
    'hi-IN':
        'प्रामिपेक्सोल भोजन के साथ या खाली पेट लिया जा सकता है; मतली होने पर भोजन के साथ लेना असुविधा कम करने में सहायक हो सकता है।',
    'es':
        'El pramipexol puede tomarse con o sin alimentos; si aparecen náuseas, tomarlo con comida puede aliviar las molestias.',
    'es-MX':
        'El pramipexol puede tomarse con o sin alimentos; si aparecen náuseas, tomarlo con comida puede ayudar a reducir las molestias.',
    'vi-VN':
        'Pramipexole có thể uống cùng hoặc không cùng bữa ăn; nếu có buồn nôn, uống cùng bữa ăn có thể giúp giảm khó chịu.',
    'th-TH':
        'พรามิเพ็กโซลรับประทานพร้อมหรือไม่พร้อมอาหารก็ได้ หากมีอาการคลื่นไส้ การรับประทานพร้อมอาหารอาจช่วยลดอาการไม่สบายตัว',
    'id-ID':
        'Pramipexole dapat diminum dengan atau tanpa makanan; jika mengalami mual, meminumnya bersama makanan dapat membantu meredakan keluhan.',
    'ru-RU':
        'Прамипексол можно принимать с пищей или натощак; при тошноте приём во время еды может уменьшить дискомфорт.',
    'pl-PL':
        'Pramipeksol można przyjmować z posiłkiem lub bez; w razie nudności przyjęcie z jedzeniem może łagodzić dolegliwości.',
    'ar-SA':
        'يمكن تناول البراميبكسول مع الطعام أو بدونه؛ إذا حدث غثيان فإن تناوله مع الطعام قد يخفف الانزعاج.',
  },
  'pd.ropinirole.food.info.v1': {
    'ko-KR':
        '로피니롤은 식사와 함께 또는 공복에 복용할 수 있으며, 서방형 제제 라벨에는 식사와 함께 복용 시 메스꺼움이 줄 수 있다고 명시되어 있지만 엄격한 제한은 아닙니다.',
    'hi-IN':
        'रोपिनिरोल भोजन के साथ या बिना लिया जा सकता है; विस्तारित-रिलीज़ रूप के लेबल पर भोजन के साथ लेने से मतली कम होने का उल्लेख है, परंतु यह कठोर प्रतिबंध नहीं है।',
    'es':
        'Ropinirol puede tomarse con o sin alimentos; el prospecto del comprimido de liberación prolongada indica que tomarlo con comida puede reducir las náuseas, aunque no es una restricción estricta.',
    'es-MX':
        'El ropinirol puede tomarse con o sin alimentos; el prospecto de la presentación de liberación prolongada indica que tomarlo con comida puede reducir las náuseas, pero no es una restricción estricta.',
    'vi-VN':
        'Ropinirole có thể uống cùng hoặc không cùng bữa ăn; nhãn dạng phóng thích kéo dài lưu ý rằng uống cùng bữa ăn có thể giảm buồn nôn, nhưng đây không phải hạn chế bắt buộc.',
    'th-TH':
        'โรปินิโรลรับประทานพร้อมหรือไม่พร้อมอาหารก็ได้ ฉลากของชนิดออกฤทธิ์เนิ่นนานระบุว่าการรับประทานพร้อมอาหารอาจช่วยลดอาการคลื่นไส้ แต่ไม่ใช่ข้อจำกัดที่เข้มงวด',
    'id-ID':
        'Ropinirole dapat diminum dengan atau tanpa makanan; label sediaan lepas lambat menyebutkan bahwa makan bersama makanan dapat mengurangi mual, tetapi ini bukan larangan ketat.',
    'ru-RU':
        'Ропинирол можно принимать с пищей или натощак; в инструкции к форме с замедленным высвобождением отмечено, что приём с пищей может уменьшить тошноту, но это не строгое ограничение.',
    'pl-PL':
        'Ropinirol można przyjmować z posiłkiem lub bez; w ulotce postaci o przedłużonym uwalnianiu zaznaczono, że posiłek może łagodzić nudności, ale nie jest to ścisłe ograniczenie.',
    'ar-SA':
        'يمكن تناول الروبينيرول مع الطعام أو بدونه؛ تشير نشرة الشكل ممتد المفعول إلى أن تناوله مع الطعام قد يقلل الغثيان، لكنه ليس قيدًا صارمًا.',
  },
  'pd.opicapone.meal.window.v1': {
    'ko-KR':
        'Opicapone의 라벨은 투약 전 1시간과 투약 후 최소 1시간 동안 식사를 피하도록 요구합니다. 현재 식사가 투약 시간과 너무 가깝습니다.',
    'hi-IN':
        'Opicapone का लेबल खुराक से 1 घंटा पहले और खुराक के बाद कम से कम 1 घंटे तक भोजन न करने की मांग करता है; वर्तमान भोजन का समय खुराक के समय के बहुत निकट है।',
    'es':
        'El prospecto de opicapone exige no comer durante 1 hora antes y al menos 1 hora después de la dosis; la comida actual está demasiado cerca de la hora de administración.',
    'es-MX':
        'El prospecto de opicapona exige no comer 1 hora antes y al menos 1 hora después de la dosis; la comida actual está demasiado cerca de la hora de administración.',
    'vi-VN':
        'Nhãn opicapone yêu cầu không ăn trong 1 giờ trước và ít nhất 1 giờ sau khi dùng thuốc; bữa ăn hiện tại quá gần với thời điểm dùng thuốc.',
    'th-TH':
        'ฉลาก opicapone กำหนดให้งดอาหาร 1 ชั่วโมงก่อนและอย่างน้อย 1 ชั่วโมงหลังให้ยา ช่วงเวลามื้ออาหารปัจจุบันอยู่ใกล้กับเวลาให้ยามากเกินไป',
    'id-ID':
        'Label opicapone mensyaratkan tidak makan selama 1 jam sebelum dan setidaknya 1 jam setelah dosis; jadwal makan saat ini terlalu dekat dengan waktu pemberian.',
    'ru-RU':
        'В инструкции опикапона требуется воздержание от пищи в течение 1 часа до и не менее 1 часа после приёма дозы; текущий приём пищи слишком близок к моменту приёма.',
    'pl-PL':
        'Ulotka opikaponu wymaga, aby nie jeść przez 1 godzinę przed i co najmniej 1 godzinę po dawce; bieżący posiłek jest zbyt blisko czasu przyjęcia.',
    'ar-SA':
        'يستلزم الملصق التعريفي للأوبيكابون الامتناع عن الطعام لمدة ساعة قبل الجرعة وساعة على الأقل بعدها؛ الوجبة الحالية قريبة جدًا من موعد الجرعة.',
  },
  'pd.rotigotine.food.independent.info.v1': {
    'ko-KR':
        'Rotigotine 패치는 경피 투여이며, 공식 라벨에는 음식이 일반적으로 흡수에 영향을 주지 않는다고 명시되어 있어 식사 시간에 맞춰 조정할 필요가 없습니다.',
    'hi-IN':
        'Rotigotine पैच त्वचीय (transdermal) रूप से दिया जाता है; आधिकारिक लेबल के अनुसार भोजन आमतौर पर अवशोषण को प्रभावित नहीं करता, इसलिए भोजन के समय पर समायोजन सामान्यतः आवश्यक नहीं है।',
    'es':
        'El parche de rotigotina se administra por vía transdérmica; el prospecto oficial indica que los alimentos no suelen afectar a la absorción, por lo que normalmente no es necesario ajustarlo a las comidas.',
    'es-MX':
        'El parche de rotigotina se administra por vía transdérmica; el prospecto oficial indica que los alimentos no suelen afectar la absorción, por lo que normalmente no requiere ajustarse a las comidas.',
    'vi-VN':
        'Miếng dán rotigotine dùng qua da; nhãn chính thức ghi rằng thực phẩm thường không ảnh hưởng đến hấp thu, do đó không cần điều chỉnh theo bữa ăn.',
    'th-TH':
        'แผ่นแปะ rotigotine ให้ยาทางผิวหนัง ฉลากทางการระบุว่าอาหารมักไม่มีผลต่อการดูดซึม จึงไม่จำเป็นต้องปรับตามเวลามื้ออาหาร',
    'id-ID':
        'Patch rotigotine diberikan secara transdermal; label resmi menyebutkan makanan umumnya tidak memengaruhi penyerapan, sehingga biasanya tidak perlu disesuaikan dengan waktu makan.',
    'ru-RU':
        'Пластырь rotigotine вводится трансдермально; в официальной инструкции указано, что пища обычно не влияет на всасывание, поэтому корректировка по времени приёма пищи обычно не нужна.',
    'pl-PL':
        'Plaster rotygotyny podawany jest przezskórnie; w oficjalnej ulotce wskazano, że pokarm zwykle nie wpływa na wchłanianie, więc dostosowanie do pór posiłków zwykle nie jest wymagane.',
    'ar-SA':
        'تُعطى لصقة الروتيغوتين عبر الجلد؛ يذكر الملصق الرسمي أن الطعام لا يؤثر عادةً على الامتصاص، لذا لا يلزم عادةً تعديل التوقيت مع الوجبات.',
  },
};
