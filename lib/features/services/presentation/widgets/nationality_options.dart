// Bundled nationality list for the traveler form (Figma BOOK-03).
// TODO(backend-contract): replace with the server's list (query `nationalities`);
// this short list covers the markets the app serves today.
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';

const _nationalities = <(String en, String ar)>[
  ('Egyptian', 'مصري'),
  ('Jordanian', 'أردني'),
  ('Saudi', 'سعودي'),
  ('Emirati', 'إماراتي'),
  ('Kuwaiti', 'كويتي'),
  ('Qatari', 'قطري'),
  ('Bahraini', 'بحريني'),
  ('Omani', 'عماني'),
  ('Yemeni', 'يمني'),
  ('Iraqi', 'عراقي'),
  ('Syrian', 'سوري'),
  ('Lebanese', 'لبناني'),
  ('Palestinian', 'فلسطيني'),
  ('Sudanese', 'سوداني'),
  ('Libyan', 'ليبي'),
  ('Tunisian', 'تونسي'),
  ('Algerian', 'جزائري'),
  ('Moroccan', 'مغربي'),
  ('Turkish', 'تركي'),
  ('Pakistani', 'باكستاني'),
  ('Indian', 'هندي'),
  ('Filipino', 'فلبيني'),
];

/// Option value is the Arabic demonym: it is what the free-text field stored before,
/// so saved drafts and the booking payload keep the same shape in either UI language.
List<FieldOption> nationalityOptions({required bool arabic}) => [
      for (final n in _nationalities)
        FieldOption(value: n.$2, label: arabic ? n.$2 : n.$1, description: arabic ? n.$1 : n.$2),
    ];
