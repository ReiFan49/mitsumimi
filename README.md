# Mitsumimi!

A ShinyColors dedicated tool to snatch most of the audio data of respective girl/unit/all.

## Story

This repository is to show you how to archive Narumi Runa voice,
the former Voice Actor of Mitsumine Yuika.
Hence the repository name is Mitsumimi.

Started on 2021 December, yields enough results until 2022 April.

## Requirements

### Software

- Ruby 2.5 or later.

### Library Requirements

Check `Gemfile` for more accurate specs.

- RubyZip 2.0 or later.

### Hidden Library Requirements

- ShinyColors Resource Reader. *Algorithm is not distributed freely due to reasons.*

### Data Requirements

- `album.json`: Containing commu listings. Obtained when you visit アルバム menu.
- `chara.json`: Array of character content. Even if it just 1, it must be in an array. Obtained when you select idols on アイドル menu.
- `consolidated.cards.json`: Consolidated Data Structure of ShinyColors cards. This contains all registered cards in the game. You cannot obtain this normally.

### Knowledge Requirements

**This repository, assumes the user, understand the risk, and how-to get ShinyColors data.**

## Instructions

As most of the program files are instantenous, requires no extra attention. I'll only explain what does each program do. Unlisted programs means it's not for execution.

### `scanner.rb`

This file scans through each JSONs and several hard-coded values to obtain voice files.
It'll take hours to complete, so please wait.
Also it caches the commu JSON to not get re-downloaded during next execution of the program.

On any case the program hits a connection/an unwanted error, try restarting the program. Always works so far.

### `zip-cleaner.rb`

This file uses `RubyZip` to examine your zip. Currently it looks for `mitsu.zip` (will be renamed later).
Zip Cleaner makes the Zip content is cleaner by removing any empty commu/voice-expected folders.

PS: Do not use WinRAR's Best compression option.

## Goal

As the time goes, I want to make this file more flexible with files.
Let's say all of these formats are strictly required.
However some parts of the program, could be adjusted by parameters.

## Disclaimer

ShinyColors and its properties are belonged to BANDAI NAMCO. I, or contributors of this repository, have tested, and not liable for any damage caused from this program on your usage.
