// The held-out quick input set for task 5.5 (METRICS.md): 30 phrases YOU
// write, the way you'd really say or type expenses, never shown to whoever
// tunes the parser. Don't write them to fit the rules; mix in what's hard
// (numbers in words, "nos", millimes, Darija, French, several items).
//
// Each entry: the phrase, then what you meant, one (label, amount) per
// item, amounts in millimes (1.500 DT = 1500). Labels are compared without
// accents or case, and loosely ("un café" matches "café").
//
// Example (delete it, it's from the rule parser's own test set):
//   ('kahwa 1.5 w taxi 8', [('kahwa', 1500), ('taxi', 8000)]),

/// (phrase, [(label, amount in millimes)]).
const heldOutPhrases = <(String, List<(String, int)>)>[
  ('j ai payé 7 dinars pour le déjeuner', [('déjeuner', 7000)]),
  ('café 1.5dt et taxi 6', [('café', 1500), ('taxi', 6000)]),
  ('deux cafés à 3 dinars', [('cafés', 3000)]),
  ('khobz 500 millimes', [('khobz', 500)]),
  ('j ai dépensé 12dt essence', [('essence', 12000)]),
  ('nos 5 dinars', [('nos', 5000)]),
  ('taxi 4 dinars w kahwa 1 dinar', [('taxi', 4000), ('kahwa', 1000)]),
  ('sandwich b 7dt', [('sandwich', 7000)]),
  ('5dt pour le bus', [('bus', 5000)]),
  ('une bouteille d eau 800 millimes', [('bouteille d eau', 800)]),
  ('lyoum صرفت 10 دنانير على الماكلة', [('makla', 10000)]),
  ('kif kif, 2dt café w 3.5dt gateau', [('café', 2000), ('gateau', 3500)]),
  ('j ai acheté un livre à vingt dinars', [('livre', 20000)]),
  ('déjeuner 8 et dîner 15', [('déjeuner', 8000), ('dîner', 15000)]),
  ('عصير ب 2500 مليم و كسكروت ب 4500', [('عصير', 2500), ('كسكروت', 4500)]),
  ('internet 25dt ce mois', [('internet', 25000)]),
  ('parking 1 dinar et essence 30dt', [('parking', 1000), ('essence', 30000)]),
  ('trois dinars pour le petit dej', [('petit dej', 3000)]),
  ('j ai payé 750 millimes pour le pain', [('pain', 750)]),
  ('shopping: t-shirt 35dt, pantalon 60', [('t-shirt', 35000), ('pantalon', 60000)]),
  ('kahwa b 1800 w jus 2500', [('kahwa', 1800), ('jus', 2500)]),
  ('ce matin café 1.2 et croissant 1.8', [('café', 1200), ('croissant', 1800)]),
  ('صرفـت خمسة دنانير تاكسي و دينارين قهوة', [('taxi', 5000), ('قهوة', 2000)]),
  ('un abonnement de quinze dinars', [('abonnement', 15000)]),
  ('حاجة للدار ب 18 دينار', [('حاجة للدار', 18000)]),
  ('déplacement 6dt, déjeuner 9dt, café 2dt', [('déplacement', 6000), ('déjeuner', 9000), ('café', 2000)]),
  ('j ai pris le train pour 4 dinars 500', [('train', 4500)]),
  ('عشرة دنانير ماكلة و 3 دنانير transport', [('ماكلة', 10000), ('transport', 3000)]),
  ('snack 2.500 dt + boisson 1.300', [('snack', 2500), ('boisson', 1300)]),
  ('hier صرفت 7dt في القهوة و 12dt في resto', [('القهوة', 7000), ('resto', 12000)]),
];
