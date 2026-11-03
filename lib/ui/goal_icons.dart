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
  GoalIconSpec(
    'desktop',
    'Компьютер',
    'Техника',
    Icons.desktop_windows_outlined,
  ),
  GoalIconSpec('keyboard', 'Клавиатура', 'Техника', Icons.keyboard_outlined),
  GoalIconSpec('mouse', 'Мышь', 'Техника', Icons.mouse_outlined),
  GoalIconSpec('printer', 'Принтер', 'Техника', Icons.print_outlined),
  GoalIconSpec('speaker', 'Колонка', 'Техника', Icons.speaker_outlined),
  GoalIconSpec('microphone', 'Микрофон', 'Техника', Icons.mic_none_outlined),
  GoalIconSpec('router', 'Роутер', 'Техника', Icons.router_outlined),
  GoalIconSpec('videocam', 'Видеокамера', 'Техника', Icons.videocam_outlined),
  GoalIconSpec('boat', 'Круиз', 'Путешествия', Icons.sailing_outlined),
  GoalIconSpec('hotel', 'Отель', 'Путешествия', Icons.hotel_outlined),
  GoalIconSpec('forest', 'Лес', 'Путешествия', Icons.forest_outlined),
  GoalIconSpec(
    'tent',
    'Палатка',
    'Путешествия',
    Icons.holiday_village_outlined,
  ),
  GoalIconSpec('passport', 'Документы', 'Путешествия', Icons.badge_outlined),
  GoalIconSpec('museum', 'Музей', 'Путешествия', Icons.museum_outlined),
  GoalIconSpec('explore', 'Открытия', 'Путешествия', Icons.explore_outlined),
  GoalIconSpec('snow', 'Зимний отдых', 'Путешествия', Icons.ac_unit_outlined),
  GoalIconSpec('lamp', 'Светильник', 'Дом', Icons.light_outlined),
  GoalIconSpec('desk', 'Рабочий стол', 'Дом', Icons.desk_outlined),
  GoalIconSpec('chair', 'Кресло', 'Дом', Icons.chair_outlined),
  GoalIconSpec('bath', 'Ванная', 'Дом', Icons.bathtub_outlined),
  GoalIconSpec(
    'washer',
    'Стиральная машина',
    'Дом',
    Icons.local_laundry_service_outlined,
  ),
  GoalIconSpec(
    'dining',
    'Обеденный стол',
    'Дом',
    Icons.table_restaurant_outlined,
  ),
  GoalIconSpec('plants', 'Растения', 'Дом', Icons.local_florist_outlined),
  GoalIconSpec('cleaning', 'Уборка', 'Дом', Icons.cleaning_services_outlined),
  GoalIconSpec(
    'dentist',
    'Стоматолог',
    'Для себя',
    Icons.medical_services_outlined,
  ),
  GoalIconSpec('glasses', 'Очки', 'Для себя', Icons.visibility_outlined),
  GoalIconSpec('haircut', 'Стрижка', 'Для себя', Icons.content_cut_outlined),
  GoalIconSpec('restaurant', 'Ресторан', 'Для себя', Icons.restaurant_outlined),
  GoalIconSpec('cake', 'День рождения', 'Для себя', Icons.cake_outlined),
  GoalIconSpec(
    'meditation',
    'Медитация',
    'Для себя',
    Icons.self_improvement_outlined,
  ),
  GoalIconSpec('run', 'Бег', 'Для себя', Icons.directions_run_outlined),
  GoalIconSpec('swim', 'Плавание', 'Для себя', Icons.pool_outlined),
  GoalIconSpec('guitar', 'Гитара', 'Увлечения', Icons.music_video_outlined),
  GoalIconSpec('piano', 'Пианино', 'Увлечения', Icons.piano_outlined),
  GoalIconSpec(
    'photo',
    'Фотография',
    'Увлечения',
    Icons.photo_library_outlined,
  ),
  GoalIconSpec('craft', 'Рукоделие', 'Увлечения', Icons.brush_outlined),
  GoalIconSpec(
    'chess',
    'Настольные игры',
    'Увлечения',
    Icons.extension_outlined,
  ),
  GoalIconSpec('skate', 'Скейтборд', 'Увлечения', Icons.skateboarding_outlined),
  GoalIconSpec('ski', 'Лыжи', 'Увлечения', Icons.downhill_skiing_outlined),
  GoalIconSpec(
    'basketball',
    'Баскетбол',
    'Увлечения',
    Icons.sports_basketball_outlined,
  ),
  GoalIconSpec('motorbike', 'Мотоцикл', 'Важное', Icons.two_wheeler_outlined),
  GoalIconSpec('license', 'Автошкола', 'Важное', Icons.drive_eta_outlined),
  GoalIconSpec('relocation', 'Переезд', 'Важное', Icons.moving_outlined),
  GoalIconSpec(
    'emergency',
    'Запас денег',
    'Важное',
    Icons.account_balance_wallet_outlined,
  ),
  GoalIconSpec(
    'graduation',
    'Диплом',
    'Важное',
    Icons.workspace_premium_outlined,
  ),
  GoalIconSpec(
    'charity',
    'Помощь',
    'Важное',
    Icons.volunteer_activism_outlined,
  ),
  GoalIconSpec('business', 'Магазин', 'Важное', Icons.storefront_outlined),
  GoalIconSpec('future', 'Будущее', 'Важное', Icons.wb_sunny_outlined),
];
GoalIconSpec goalIconById(String id) =>
    goalIcons.where((item) => item.id == id).firstOrNull ?? goalIcons.first;

class GoalSymbol extends StatelessWidget {
  final String id;
  final double size;
  final bool tile, selected;
  const GoalSymbol(
    this.id, {
    super.key,
    this.size = 22,
    this.tile = true,
    this.selected = false,
  });
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
                border: Border.all(
                  color: selected ? KopiColors.berry : Colors.transparent,
                  width: 1.5,
                ),
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
      child: LayoutBuilder(
        builder: (context, bounds) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          final height = (MediaQuery.sizeOf(context).height * .78).clamp(
            0.0,
            (bounds.maxHeight - keyboard).clamp(0.0, double.infinity),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SizedBox(
              height: height,
              child: CustomScrollView(
                key: const ValueKey('goal-icon-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Heading('Значок мечты', size: 24),
                          ),
                          IconButton(
                            tooltip: 'Закрыть выбор значка',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          hintText: 'Поиск значка',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
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
                                onSelected: (_) =>
                                    setState(() => group = category),
                                selectedColor: KopiColors.soft,
                                showCheckmark: false,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Такого значка пока нет. Попробуй другое слово.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final textHeight =
                              MediaQuery.textScalerOf(context).scale(11) * 1.25;
                          final columns =
                              (constraints.crossAxisExtent /
                                      (textHeight > 17 ? 104 : 80))
                                  .floor()
                                  .clamp(2, 6);
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 52 + textHeight * 2,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = filtered[index];
                              final selected = item.id == widget.selected;
                              return Semantics(
                                label: item.label,
                                selected: selected,
                                button: true,
                                child: InkWell(
                                  key: ValueKey('choose-icon-${item.id}'),
                                  onTap: () => Navigator.pop(context, item.id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: ExcludeSemantics(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 3,
                                      ),
                                      child: Column(
                                        children: [
                                          GoalSymbol(
                                            item.id,
                                            selected: selected,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1.25,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: filtered.length),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
