# Element Alchemy

A merge-and-discover crafting game (Little Alchemy style) built with Flutter.
Start with Water, Fire, Earth and Air and combine them to discover 147 more elements.

## Features
- Little Alchemy style board: drag elements from the scrollable list on the right onto the empty board (or tap them to add), then drop one element on another to merge (drag two copies for self-merges like Air + Air)
- **Clear** button empties the board; drag an element onto the **Bin** to delete just that one
- 151 elements / 161 recipes, each with its own unique emoji stored in `assets/recipes.json`
- Coins: +5 per discovery; **hint system** costs 10 coins
- **Daily challenge**: a new target element every day, +25 coins and a streak
- Search bar, NEW badges, pop and shake animations, haptics
- Progress screen with discovery log (timestamps) and reset
- Progress saved locally with `shared_preferences`

## Run
```
flutter pub get
flutter run
```

## Structure
- `lib/state/game_state.dart` - all game rules, saving, hints, daily challenge
- `lib/screens/` - Play, Daily and Progress tabs
- `lib/widgets/` - draggable element chip and dialogs
- `assets/recipes.json` - add new elements and recipes here (recipe keys are the two ids sorted alphabetically, joined with `+`)
