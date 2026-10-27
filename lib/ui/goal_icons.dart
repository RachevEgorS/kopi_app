import 'package:flutter/material.dart';
import 'design.dart';

class GoalIconSpec {
  final String id, label, group;
  final IconData icon;
  final Glyph? line;
  const GoalIconSpec(this.id, this.label, this.group, this.icon, [this.line]);
  Color get color => switch (group) {
    'Техника' => KopiColors.lavender,
    'Путешествия' => KopiColors.sage,
    'Дом' => KopiColors.sand,
    'Для себя' => KopiColors.soft,
    'Увлечения' => const Color(0xFFD6E4E0),
    _ => const Color(0xFFE9DCC7),
  };
}

const goalIcons = [
  GoalIconSpec(
    'laptop',
    'Ноутбук',
    'Техника',
    Icons.laptop_outlined,
    Glyph.laptop,
  ),
  GoalIconSpec('phone', 'Телефон', 'Техника', Icons.smartphone_outlined),
  GoalIconSpec('tablet', 'Планшет', 'Техника', Icons.tablet_mac_outlined),
  GoalIconSpec('headphones', 'Наушники', 'Техника', Icons.headphones_outlined),
  GoalIconSpec('camera', 'Камера', 'Техника', Icons.photo_camera_outlined),
  GoalIconSpec('watch', 'Часы', 'Техника', Icons.watch_outlined),
  GoalIconSpec('tv', 'Телевизор', 'Техника', Icons.tv_outlined),
  GoalIconSpec(
    'console',
    'Приставка',
    'Техника',
    Icons.sports_esports_outlined,
  ),
  GoalIconSpec('leaf', 'Листок', 'Путешествия', Icons.eco_outlined, Glyph.leaf),
  GoalIconSpec('plane', 'Перелёт', 'Путешествия', Icons.flight_outlined),
  GoalIconSpec('beach', 'Море', 'Путешествия', Icons.beach_access_outlined),
  GoalIconSpec('mountain', 'Горы', 'Путешествия', Icons.landscape_outlined),
  GoalIconSpec('luggage', 'Чемодан', 'Путешествия', Icons.luggage_outlined),
  GoalIconSpec('camping', 'Поход', 'Путешествия', Icons.hiking_outlined),
  GoalIconSpec('train', 'Поезд', 'Путешествия', Icons.train_outlined),
  GoalIconSpec('world', 'Весь мир', 'Путешествия', Icons.public_outlined),
  GoalIconSpec('home', 'Квартира', 'Дом', Icons.home_outlined),
  GoalIconSpec('keys', 'Ключи', 'Дом', Icons.key_outlined),
  GoalIconSpec('sofa', 'Диван', 'Дом', Icons.weekend_outlined),
  GoalIconSpec('bed', 'Кровать', 'Дом', Icons.bed_outlined),
  GoalIconSpec('kitchen', 'Кухня', 'Дом', Icons.kitchen_outlined),
  GoalIconSpec('repair', 'Ремонт', 'Дом', Icons.handyman_outlined),
  GoalIconSpec('garden', 'Сад', 'Дом', Icons.yard_outlined),
  GoalIconSpec('coffee', 'Кофемашина', 'Дом', Icons.coffee_outlined),
  GoalIconSpec('health', 'Здоровье', 'Для себя', Icons.favorite_border),
  GoalIconSpec('spa', 'Отдых', 'Для себя', Icons.spa_outlined),
  GoalIconSpec('fitness', 'Спорт', 'Для себя', Icons.fitness_center_outlined),
  GoalIconSpec('style', 'Гардероб', 'Для себя', Icons.checkroom_outlined),
  GoalIconSpec('gift', 'Подарок', 'Для себя', Icons.card_giftcard_outlined),
  GoalIconSpec('pet', 'Питомец', 'Для себя', Icons.pets_outlined),
  GoalIconSpec(
    'child',
    'Для ребёнка',
    'Для себя',
    Icons.child_friendly_outlined,
  ),
  GoalIconSpec(
    'celebration',
    'Праздник',
    'Для себя',
    Icons.celebration_outlined,
  ),
  GoalIconSpec('book', 'Книги', 'Увлечения', Icons.menu_book_outlined),
  GoalIconSpec('education', 'Обучение', 'Увлечения', Icons.school_outlined),
  GoalIconSpec('music', 'Музыка', 'Увлечения', Icons.music_note_outlined),
  GoalIconSpec('art', 'Творчество', 'Увлечения', Icons.palette_outlined),
  GoalIconSpec(
    'bike',
    'Велосипед',
    'Увлечения',
    Icons.directions_bike_outlined,
  ),
  GoalIconSpec('cinema', 'Кино', 'Увлечения', Icons.movie_outlined),
  GoalIconSpec(
    'ticket',
    'Концерт',
    'Увлечения',
    Icons.confirmation_number_outlined,
  ),
  GoalIconSpec('sport', 'Мяч', 'Увлечения', Icons.sports_soccer_outlined),
  GoalIconSpec('flag', 'Моя мечта', 'Важное', Icons.flag_outlined, Glyph.flag),
  GoalIconSpec('savings', 'Копилка', 'Важное', Icons.savings_outlined),
  GoalIconSpec('security', 'Подушка', 'Важное', Icons.shield_outlined),
  GoalIconSpec('car', 'Машина', 'Важное', Icons.directions_car_outlined),
  GoalIconSpec('work', 'Своё дело', 'Важное', Icons.work_outline),
  GoalIconSpec('family', 'Семья', 'Важное', Icons.family_restroom_outlined),
  GoalIconSpec('ring', 'Свадьба', 'Важное', Icons.diamond_outlined),
  GoalIconSpec(
    'star',
    'Особенная цель',
    'Важное',
    Icons.star_border,
    Glyph.star,
  ),
];
GoalIconSpec goalIconById(String id) =>
    goalIcons.where((item) => item.id == id).firstOrNull ?? goalIcons.first;

class GoalSymbol extends StatelessWidget {
  final String id;
  final double size;
  final bool tile;
  const GoalSymbol(this.id, {super.key, this.size = 22, this.tile = true});
  @override
  Widget build(BuildContext context) {
    final spec = goalIconById(id);
    final symbol = spec.line == null
        ? Icon(spec.icon, size: size, color: KopiColors.berry)
        : LineIcon(spec.line!, size: size, color: KopiColors.berry);
    return ExcludeSemantics(
      child: tile
          ? Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: spec.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: symbol,
            )
          : symbol,
    );
  }
}

Future<String?> chooseGoalIcon(BuildContext context, String selected) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: KopiColors.background,
      builder: (_) => GoalIconPicker(selected: selected),
    );

class GoalIconPicker extends StatefulWidget {
  final String selected;
  const GoalIconPicker({super.key, required this.selected});
  @override
  State<GoalIconPicker> createState() => _GoalIconPickerState();
}

class _GoalIconPickerState extends State<GoalIconPicker> {
  String query = '', group = 'Все';
  @override
  Widget build(BuildContext context) {
    final filtered = goalIcons
        .where(
          (item) =>
              (group == 'Все' || item.group == group) &&
              '${item.label} ${item.group}'.toLowerCase().contains(
                query.toLowerCase().trim(),
              ),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 12, 10),
                child: Row(
                  children: [
                    const Expanded(child: Heading('Значок мечты', size: 25)),
                    IconButton(
                      tooltip: 'Закрыть выбор значка',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Найти: море, машина, книги…',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 62,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  children: [
                    for (final category in [
                      'Все',
                      ...goalIcons.map((i) => i.group).toSet(),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            category,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: category == group,
                          onSelected: (_) => setState(() => group = category),
                          selectedColor: KopiColors.soft,
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Такого значка пока нет. Попробуй другое слово.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, bounds) => GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: ((bounds.maxWidth - 40) / 80)
                                    .floor()
                                    .clamp(2, 6),
                                mainAxisExtent:
                                    72 +
                                    MediaQuery.textScalerOf(context).scale(11) *
                                        2.8,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final selected = item.id == widget.selected;
                            return Semantics(
                              label: item.label,
                              selected: selected,
                              button: true,
                              child: InkWell(
                                key: ValueKey('choose-icon-${item.id}'),
                                onTap: () => Navigator.pop(context, item.id),
                                borderRadius: BorderRadius.circular(14),
                                child: ExcludeSemantics(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: selected
                                            ? KopiColors.berry
                                            : Colors.transparent,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      color: selected
                                          ? KopiColors.soft.withValues(
                                              alpha: .35,
                                            )
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        GoalSymbol(item.id),
                                        const SizedBox(height: 7),
                                        Text(
                                          item.label,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
