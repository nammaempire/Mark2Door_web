import 'package:flutter/material.dart';

import 'theme.dart';

/// One pickable emoji and the words an admin might search it by.
typedef EmojiOption = ({String emoji, String name});

/// Emojis for a store catalogue, grouped the way the picker shows them.
/// An emoji appears in one group only.
const kEmojiGroups = <({String label, List<EmojiOption> options})>[
  (
    label: 'Fruits',
    options: [
      (emoji: '🍎', name: 'apple'),
      (emoji: '🍏', name: 'green apple'),
      (emoji: '🍌', name: 'banana'),
      (emoji: '🍊', name: 'orange'),
      (emoji: '🍋', name: 'lemon'),
      (emoji: '🍉', name: 'watermelon'),
      (emoji: '🍇', name: 'grapes'),
      (emoji: '🍓', name: 'strawberry'),
      (emoji: '🫐', name: 'blueberries'),
      (emoji: '🍒', name: 'cherries'),
      (emoji: '🍑', name: 'peach'),
      (emoji: '🥭', name: 'mango'),
      (emoji: '🍍', name: 'pineapple'),
      (emoji: '🥥', name: 'coconut'),
      (emoji: '🥝', name: 'kiwi'),
      (emoji: '🍐', name: 'pear'),
      (emoji: '🍈', name: 'melon'),
    ],
  ),
  (
    label: 'Vegetables',
    options: [
      (emoji: '🥦', name: 'broccoli'),
      (emoji: '🥬', name: 'leafy greens spinach'),
      (emoji: '🥕', name: 'carrot'),
      (emoji: '🍅', name: 'tomato'),
      (emoji: '🧅', name: 'onion'),
      (emoji: '🧄', name: 'garlic'),
      (emoji: '🥔', name: 'potato'),
      (emoji: '🍠', name: 'sweet potato'),
      (emoji: '🌽', name: 'corn'),
      (emoji: '🥒', name: 'cucumber'),
      (emoji: '🍆', name: 'brinjal eggplant'),
      (emoji: '🫑', name: 'capsicum bell pepper'),
      (emoji: '🌶️', name: 'chilli'),
      (emoji: '🍄', name: 'mushroom'),
      (emoji: '🥑', name: 'avocado'),
      (emoji: '🫒', name: 'olive'),
      (emoji: '🥜', name: 'peanuts groundnut'),
      (emoji: '🌰', name: 'chestnut nuts'),
      (emoji: '🌿', name: 'herbs coriander mint'),
      (emoji: '🥗', name: 'salad'),
    ],
  ),
  (
    label: 'Dairy & eggs',
    options: [
      (emoji: '🥛', name: 'milk'),
      (emoji: '🧈', name: 'butter'),
      (emoji: '🧀', name: 'cheese paneer'),
      (emoji: '🥚', name: 'egg'),
      (emoji: '🍳', name: 'fried egg omelette'),
      (emoji: '🥣', name: 'curd yogurt bowl cereal'),
      (emoji: '🍦', name: 'ice cream cone'),
      (emoji: '🍨', name: 'ice cream cup'),
    ],
  ),
  (
    label: 'Bakery & staples',
    options: [
      (emoji: '🍞', name: 'bread'),
      (emoji: '🥖', name: 'baguette'),
      (emoji: '🥐', name: 'croissant'),
      (emoji: '🥯', name: 'bagel bun'),
      (emoji: '🫓', name: 'roti chapati flatbread'),
      (emoji: '🥞', name: 'pancakes dosa'),
      (emoji: '🧇', name: 'waffle'),
      (emoji: '🌾', name: 'wheat atta grains'),
      (emoji: '🍚', name: 'rice'),
      (emoji: '🍜', name: 'noodles'),
      (emoji: '🍝', name: 'pasta'),
      (emoji: '🧂', name: 'salt spices masala'),
      (emoji: '🍯', name: 'honey'),
      (emoji: '🥫', name: 'canned food'),
      (emoji: '🌻', name: 'sunflower oil'),
    ],
  ),
  (
    label: 'Meat & seafood',
    options: [
      (emoji: '🍗', name: 'chicken leg'),
      (emoji: '🍖', name: 'meat'),
      (emoji: '🥩', name: 'mutton steak'),
      (emoji: '🥓', name: 'bacon'),
      (emoji: '🐔', name: 'chicken'),
      (emoji: '🐟', name: 'fish'),
      (emoji: '🍤', name: 'fried prawn'),
      (emoji: '🦐', name: 'prawn shrimp'),
      (emoji: '🦀', name: 'crab'),
      (emoji: '🦑', name: 'squid'),
    ],
  ),
  (
    label: 'Snacks & sweets',
    options: [
      (emoji: '🍿', name: 'popcorn snacks'),
      (emoji: '🍪', name: 'biscuit cookie'),
      (emoji: '🍫', name: 'chocolate'),
      (emoji: '🍬', name: 'candy toffee'),
      (emoji: '🍭', name: 'lollipop'),
      (emoji: '🍩', name: 'doughnut'),
      (emoji: '🧁', name: 'cupcake'),
      (emoji: '🍰', name: 'cake pastry'),
      (emoji: '🎂', name: 'birthday cake'),
      (emoji: '🥨', name: 'pretzel namkeen'),
      (emoji: '🍟', name: 'fries chips'),
      (emoji: '🍮', name: 'pudding dessert'),
      (emoji: '🍡', name: 'sweets mithai'),
      (emoji: '🥧', name: 'pie'),
    ],
  ),
  (
    label: 'Beverages',
    options: [
      (emoji: '🧃', name: 'juice'),
      (emoji: '🥤', name: 'soft drink cola'),
      (emoji: '☕', name: 'coffee'),
      (emoji: '🍵', name: 'tea'),
      (emoji: '🫖', name: 'teapot'),
      (emoji: '🧋', name: 'milkshake bubble tea'),
      (emoji: '🍹', name: 'mocktail'),
      (emoji: '💧', name: 'water'),
      (emoji: '🧊', name: 'ice'),
    ],
  ),
  (
    label: 'Ready to eat',
    options: [
      (emoji: '🍕', name: 'pizza'),
      (emoji: '🍔', name: 'burger'),
      (emoji: '🌭', name: 'hot dog'),
      (emoji: '🥪', name: 'sandwich'),
      (emoji: '🌮', name: 'taco'),
      (emoji: '🌯', name: 'wrap roll'),
      (emoji: '🥙', name: 'stuffed flatbread shawarma'),
      (emoji: '🍛', name: 'curry rice biryani'),
      (emoji: '🍲', name: 'stew soup'),
      (emoji: '🥘', name: 'curry pan'),
      (emoji: '🍱', name: 'meal box'),
      (emoji: '🥟', name: 'momo dumpling samosa'),
      (emoji: '🍣', name: 'sushi'),
      (emoji: '🥡', name: 'takeaway box'),
    ],
  ),
  (
    label: 'Household & cleaning',
    options: [
      (emoji: '🧼', name: 'soap'),
      (emoji: '🧽', name: 'sponge scrubber'),
      (emoji: '🧹', name: 'broom'),
      (emoji: '🧺', name: 'laundry basket detergent'),
      (emoji: '🧻', name: 'tissue roll'),
      (emoji: '🪣', name: 'bucket'),
      (emoji: '🗑️', name: 'dustbin garbage bags'),
      (emoji: '🚿', name: 'shower'),
      (emoji: '🛁', name: 'bath'),
      (emoji: '🕯️', name: 'candle'),
      (emoji: '💡', name: 'bulb light'),
      (emoji: '🔋', name: 'battery'),
    ],
  ),
  (
    label: 'Personal care & health',
    options: [
      (emoji: '🧴', name: 'lotion shampoo bottle'),
      (emoji: '🪥', name: 'toothbrush toothpaste'),
      (emoji: '🪒', name: 'razor shaving'),
      (emoji: '💄', name: 'lipstick makeup'),
      (emoji: '💅', name: 'nail polish'),
      (emoji: '🪞', name: 'mirror'),
      (emoji: '👓', name: 'glasses'),
      (emoji: '💊', name: 'medicine tablets'),
      (emoji: '🩹', name: 'bandage first aid'),
      (emoji: '🌡️', name: 'thermometer'),
      (emoji: '😷', name: 'mask'),
    ],
  ),
  (
    label: 'Baby & kids',
    options: [
      (emoji: '🍼', name: 'baby bottle'),
      (emoji: '👶', name: 'baby'),
      (emoji: '🧷', name: 'safety pin diaper'),
      (emoji: '🧸', name: 'teddy toy'),
      (emoji: '🪀', name: 'yo-yo toy'),
      (emoji: '🧩', name: 'puzzle'),
      (emoji: '🎈', name: 'balloon'),
    ],
  ),
  (
    label: 'Pets',
    options: [
      (emoji: '🐾', name: 'paw pet'),
      (emoji: '🐶', name: 'dog'),
      (emoji: '🐱', name: 'cat'),
      (emoji: '🐠', name: 'aquarium fish'),
      (emoji: '🐦', name: 'bird'),
      (emoji: '🐰', name: 'rabbit'),
      (emoji: '🐹', name: 'hamster'),
      (emoji: '🦴', name: 'bone pet food'),
    ],
  ),
  (
    label: 'Fashion',
    options: [
      (emoji: '👕', name: 't-shirt'),
      (emoji: '👔', name: 'shirt'),
      (emoji: '👖', name: 'jeans trousers'),
      (emoji: '👗', name: 'dress'),
      (emoji: '🥻', name: 'saree'),
      (emoji: '🧥', name: 'jacket coat'),
      (emoji: '👟', name: 'sneakers shoes'),
      (emoji: '👞', name: 'formal shoes'),
      (emoji: '👠', name: 'heels'),
      (emoji: '🩴', name: 'slippers'),
      (emoji: '🧦', name: 'socks'),
      (emoji: '🧢', name: 'cap'),
      (emoji: '👜', name: 'handbag'),
      (emoji: '🎒', name: 'backpack bag'),
      (emoji: '⌚', name: 'watch'),
      (emoji: '🕶️', name: 'sunglasses'),
      (emoji: '💍', name: 'ring jewellery'),
      (emoji: '👑', name: 'crown premium'),
    ],
  ),
  (
    label: 'Electronics',
    options: [
      (emoji: '📱', name: 'mobile phone'),
      (emoji: '💻', name: 'laptop'),
      (emoji: '🖥️', name: 'desktop monitor'),
      (emoji: '⌨️', name: 'keyboard'),
      (emoji: '🖱️', name: 'mouse'),
      (emoji: '🎧', name: 'headphones'),
      (emoji: '🔊', name: 'speaker'),
      (emoji: '📷', name: 'camera'),
      (emoji: '📺', name: 'tv television'),
      (emoji: '🎮', name: 'gaming'),
      (emoji: '🖨️', name: 'printer'),
      (emoji: '🔌', name: 'plug charger'),
      (emoji: '⏰', name: 'clock'),
    ],
  ),
  (
    label: 'Home & kitchen',
    options: [
      (emoji: '🍽️', name: 'plate dinner set'),
      (emoji: '🍴', name: 'cutlery fork'),
      (emoji: '🥄', name: 'spoon'),
      (emoji: '🔪', name: 'knife'),
      (emoji: '🥢', name: 'chopsticks'),
      (emoji: '🏺', name: 'pot vase'),
      (emoji: '🛏️', name: 'bed bedsheet'),
      (emoji: '🛋️', name: 'sofa'),
      (emoji: '🪑', name: 'chair'),
      (emoji: '🪴', name: 'plant'),
      (emoji: '🖼️', name: 'frame decor'),
      (emoji: '🧰', name: 'toolbox'),
      (emoji: '🔨', name: 'hammer tools'),
      (emoji: '🪛', name: 'screwdriver'),
      (emoji: '🧵', name: 'thread sewing'),
      (emoji: '☂️', name: 'umbrella'),
    ],
  ),
  (
    label: 'Books, sports & gifts',
    options: [
      (emoji: '📚', name: 'books'),
      (emoji: '📓', name: 'notebook'),
      (emoji: '✏️', name: 'pencil'),
      (emoji: '🖊️', name: 'pen'),
      (emoji: '✂️', name: 'scissors'),
      (emoji: '📎', name: 'clip stationery'),
      (emoji: '🎨', name: 'art colours'),
      (emoji: '⚽', name: 'football'),
      (emoji: '🏏', name: 'cricket'),
      (emoji: '🏸', name: 'badminton'),
      (emoji: '🏀', name: 'basketball'),
      (emoji: '🎾', name: 'tennis'),
      (emoji: '🚲', name: 'cycle'),
      (emoji: '🎸', name: 'guitar music'),
      (emoji: '🪔', name: 'diya festival pooja'),
      (emoji: '🎁', name: 'gift'),
      (emoji: '🌸', name: 'flowers'),
      (emoji: '💐', name: 'bouquet'),
    ],
  ),
  (
    label: 'Offers & shopping',
    options: [
      (emoji: '🛒', name: 'cart shopping'),
      (emoji: '🛍️', name: 'shopping bags'),
      (emoji: '🏷️', name: 'tag price offer'),
      (emoji: '💰', name: 'money savings'),
      (emoji: '💸', name: 'discount cashback'),
      (emoji: '🔥', name: 'hot deal'),
      (emoji: '⚡', name: 'flash sale'),
      (emoji: '🆕', name: 'new arrival'),
      (emoji: '🆓', name: 'free'),
      (emoji: '💯', name: 'hundred best'),
      (emoji: '⭐', name: 'star'),
      (emoji: '🌟', name: 'glowing star special'),
      (emoji: '🥇', name: 'best seller'),
      (emoji: '🎉', name: 'party celebration'),
      (emoji: '🎊', name: 'confetti festival'),
      (emoji: '❤️', name: 'love favourite'),
      (emoji: '👍', name: 'thumbs up'),
      (emoji: '🚚', name: 'delivery truck'),
      (emoji: '🛵', name: 'scooter delivery'),
      (emoji: '📦', name: 'package box'),
      (emoji: '⏱️', name: 'fast timer'),
      (emoji: '🏪', name: 'store shop'),
      (emoji: '☀️', name: 'summer sun'),
      (emoji: '❄️', name: 'winter cold frozen'),
      (emoji: '🌧️', name: 'monsoon rain'),
    ],
  ),
];

const _emojiStyle = TextStyle(
  fontSize: 24,
  height: 1.1,
  fontFamilyFallback: ['Noto Color Emoji'],
);

/// A form field that shows the chosen emoji and opens the picker when
/// clicked, so admins choose from a list instead of typing an emoji.
class EmojiPickerField extends StatelessWidget {
  const EmojiPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Emoji',
    this.allowNone = false,
  });

  /// The chosen emoji; empty when none.
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  /// Adds a "No emoji" choice that reports an empty string.
  final bool allowNone;

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _EmojiPickerDialog(selected: value, allowNone: allowNone),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: value.isEmpty
            ? const Text('None', style: TextStyle(color: AppColors.textMuted))
            : Text(value, style: _emojiStyle),
      ),
    );
  }
}

class _EmojiPickerDialog extends StatefulWidget {
  const _EmojiPickerDialog({required this.selected, required this.allowNone});

  final String selected;
  final bool allowNone;

  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final words = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    bool matches(String label, EmojiOption o) {
      final haystack = '${o.name} ${label.toLowerCase()}';
      return words.every(haystack.contains);
    }

    final groups = [
      for (final g in kEmojiGroups)
        (
          label: g.label,
          options: [
            for (final o in g.options)
              if (matches(g.label, o)) o,
          ],
        ),
    ].where((g) => g.options.isNotEmpty).toList(growable: false);

    return AlertDialog(
      title: const Text('Choose an emoji'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('emoji-search'),
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search, for example "milk" or "offer"',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Text(
                        'No emoji matches that search.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
                              child: Text(
                                g.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final o in g.options)
                                  _EmojiChoice(
                                    option: o,
                                    selected: o.emoji == widget.selected,
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.allowNone)
          TextButton(
            key: const ValueKey('emoji-none'),
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('No emoji'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _EmojiChoice extends StatelessWidget {
  const _EmojiChoice({required this.option, required this.selected});

  final EmojiOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: option.name,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        key: ValueKey('emoji-${option.emoji}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(option.emoji),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(option.emoji, style: _emojiStyle),
        ),
      ),
    );
  }
}
