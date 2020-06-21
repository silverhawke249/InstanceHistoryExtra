# Instance History Extra
A WoW Classic addon that tracks your recently entered instances and lets you know when you are potentially locked out.

![Preview of addon in action.](https://silverhawke.s-ul.eu/Kl4116VN)

This addon...

* Handles both the "30 instances per day" and the "5 instances per hour" limit.
  * It also handles the 30-minute auto-reset case!
* Shows the duration you spent in an instance as a progress bar. The progress bar represents 24 hours or 1 hour, depending on how many instances you have entered recently.
* Displays expected time until more instances are available.
* Works in most cases, but most notably it cannot detect if a reset is done, the user is not the party leader, and the party leader doesn't use this addon.
  * For this case, typing `/ihex forcereset` will allow the addon to count the next instance correctly.

## Installing
~~Downloading from [CurseForge](https://www.curseforge.com/wow/addons/instancehistoryextra) is recommended.~~ CurseForge download under construction. Download or clone from GitHub.

## Configuration
Type `/ihex` or go to `Main Menu → Interface Options → AddOns → Instance History Extra`.

## Acknowledgements
Most of the code was based on the [Instance History](https://wago.io/OXlZupyKm) WeakAura, which was in turn based on the [SavedInstance](https://www.curseforge.com/wow/addons/saved_instances) addon.

## License
Copyright © 2020 silverhawke | [MIT License](https://opensource.org/licenses/MIT)
