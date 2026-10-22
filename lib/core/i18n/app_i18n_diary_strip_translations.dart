/// Day-strip copy on Insights: the account holder's own medication, meal and
/// self-reported motor-state entries on a 24-hour line, plus descriptive
/// counts. Other language families fall back to English pending
/// native-language review; key and placeholder parity is checked by tests.
const Map<String, Map<String, String>> kDiaryStripTranslations = {
  'en': {
    'diary.title': 'Day strip: medication, meals and motor state',
    'diary.subtitle':
        'Your own entries on a 24-hour line ({zone}). Each mark is one entry; nothing is filled in between entries.',
    'diary.previous_day': 'Previous day',
    'diary.next_day': 'Next day',
    'diary.today': 'Today',
    'diary.showing_day': 'Showing {date}',
    'diary.lane_medication': 'Medication intakes',
    'diary.lane_meals': 'Meals and logged protein',
    'diary.lane_motor': 'Motor state (self-reported)',
    'diary.none': 'None recorded',
    'diary.protein_known': '{grams} g protein',
    'diary.protein_unknown': 'protein unknown',
    'diary.protein_invalid': 'protein value invalid',
    'diary.dose_unknown': 'dose not recorded',
    'diary.state_on': 'ON',
    'diary.state_off': 'OFF',
    'diary.state_uncertain': 'Uncertain',
    'diary.motor_without_state':
        '{count} motor-state entries were saved as unknown or not measured and are not drawn.',
    'diary.no_entries_day':
        'No medication, meal or motor-state entries on this day.',
    'diary.future_excluded':
        '{count} future-dated entries in these dates are not shown.',
    'diary.week_title': 'Seven days ending on the shown day',
    'diary.week_subtitle':
        'One row per day: medication on top, meals in the middle, motor state below. Choose a row to show that day.',
    'diary.week_row':
        '{date}: {doses} medication intakes, {meals} meals, ON {on}, OFF {off}, uncertain {uncertain}. Show this day.',
    'diary.legend_medication': 'Medication',
    'diary.legend_meal_known': 'Meal, protein logged',
    'diary.legend_meal_unknown': 'Meal, protein unknown',
    'diary.counts_title': 'Counts from your entries',
    'diary.counts_range': 'Dates {start} — {end} ({zone}).',
    'diary.counts_filter': 'Meals counted: protein logged at or above',
    'diary.counts_filter_note':
        'This filter only chooses which logged meals are counted. It is not a target or a limit.',
    'diary.filter_option': '{grams} g',
    'diary.count_off':
        'OFF entries recorded within {hours} h after a meal logged with at least {grams} g protein: {n} of {m}.',
    'diary.count_on':
        'ON entries recorded within {hours} h after a meal logged with at least {grams} g protein: {n} of {m}.',
    'diary.count_uncertain':
        'Uncertain entries recorded within {hours} h after a meal logged with at least {grams} g protein: {n} of {m}.',
    'diary.count_unclassified':
        '{count} more could not be counted either way because a meal in the {hours} h before had unknown protein.',
    'diary.counts_boundary':
        'These counts describe your own records only. They do not show that a meal caused a motor state, they do not predict anything, and they are not a clinical assessment. This is not medical advice; questions about patterns are for your clinician.',
  },
  'zh': {
    'diary.title': '日内记录条：用药、进餐与运动状态',
    'diary.subtitle': '你本人的记录按 24 小时排列（{zone}）。每个标记是一条记录；记录之间的时间不作推断。',
    'diary.previous_day': '前一天',
    'diary.next_day': '后一天',
    'diary.today': '今天',
    'diary.showing_day': '正在显示 {date}',
    'diary.lane_medication': '服药记录',
    'diary.lane_meals': '进餐与记录的蛋白质',
    'diary.lane_motor': '运动状态（本人自报）',
    'diary.none': '无记录',
    'diary.protein_known': '蛋白质 {grams} 克',
    'diary.protein_unknown': '蛋白质未知',
    'diary.protein_invalid': '蛋白质数值无效',
    'diary.dose_unknown': '未记录剂量',
    'diary.state_on': 'ON',
    'diary.state_off': 'OFF',
    'diary.state_uncertain': '不确定',
    'diary.motor_without_state': '另有 {count} 条运动状态记录为未知或未测量，未在图中显示。',
    'diary.no_entries_day': '这一天没有服药、进餐或运动状态记录。',
    'diary.future_excluded': '这些日期内另有 {count} 条未来时间记录，未显示。',
    'diary.week_title': '截至所显示日期的七天',
    'diary.week_subtitle': '每天一行：上方为用药，中间为进餐，下方为运动状态。选择一行可显示当天。',
    'diary.week_row':
        '{date}：服药 {doses} 次，进餐 {meals} 次，ON {on} 条，OFF {off} 条，不确定 {uncertain} 条。显示这一天。',
    'diary.legend_medication': '用药',
    'diary.legend_meal_known': '进餐，已记录蛋白质',
    'diary.legend_meal_unknown': '进餐，蛋白质未知',
    'diary.counts_title': '根据你的记录计数',
    'diary.counts_range': '日期 {start} — {end}（{zone}）。',
    'diary.counts_filter': '计入的餐次：记录的蛋白质不少于',
    'diary.counts_filter_note': '此筛选只决定哪些已记录的餐次被计入，不是目标或限量。',
    'diary.filter_option': '{grams} 克',
    'diary.count_off':
        '在记录蛋白质不少于 {grams} 克的一餐之后 {hours} 小时内记录的 OFF：{m} 条中有 {n} 条。',
    'diary.count_on':
        '在记录蛋白质不少于 {grams} 克的一餐之后 {hours} 小时内记录的 ON：{m} 条中有 {n} 条。',
    'diary.count_uncertain':
        '在记录蛋白质不少于 {grams} 克的一餐之后 {hours} 小时内记录的“不确定”：{m} 条中有 {n} 条。',
    'diary.count_unclassified':
        '另有 {count} 条无法归入任何一类，因为之前 {hours} 小时内有一餐蛋白质未知。',
    'diary.counts_boundary':
        '这些计数只描述你本人的记录，不说明某餐导致了某种运动状态，不作任何预测，也不是临床评估。这不是医疗建议；关于规律的疑问请与临床医生讨论。',
  },
};
