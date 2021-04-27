# wave-amp2
### wave-amp2 is a fully-featured music player for  CC: Tweaked, based on [wave-amp](http://www.computercraft.info/forums2/index.php?/topic/28091-wave-amp-a-fully-featured-music-player/) powered by [wave](https://github.com/CrazedProgrammer/wave).

This is a modified version that works with the CC: Tweaked mod for 1.16.4.
It can use commands on a Command Computer or Speakers on normal Computers. (No other mods required)

![wave-amp2](https://cdn.bjmsw.net/img/wave-amp2.png)

## Features:
- Updated for CC: Tweaked using 1.16 commands or CC: Tweaked speakers
- Plays NBS (Note Block Studio) files
  - wave-amp will automatically load all .nbs files on your CC: Tweaked computer.
- Cool UI
- Music visualiser
- Different play modes (normal, stop, repeat, shuffle)
- Custom themes
- Flexibility through command-line arguments

## Set-Up
- Either place a command computer or a advanced computer
- If using command computers no further steps are required
- If using non-command computers you need at least one speaker connected to your computer
  - You can connect them via network cables or just place them next to the computer

## Installation

### Program
- wave-amp2 `pastebin get nKyXwuuf wave-amp2`
### Themes
- dark theme `pastebin get HYrhP1yN darktheme`
- red theme `pastebin get EP0vBAa5 redtheme`
### Some example Songs
- `pastebin get cUYTGbpb bbpack`
- `bbpack get CYRmLz78 Songs`
> Thanks to [Bomb Bloke](http://www.computercraft.info/forums2/index.php?/user/15121-bomb-bloke/) [(Original Comment)](http://www.computercraft.info/forums2/index.php?/topic/28091-wave-amp-a-fully-featured-music-player/page__view__findpost__p__262827)

## Make your own songs
wave-amp2 uses nbs files for music storage. You can create your own songs using [Note Block Studio](https://www.stuffbydavid.com/mcnbs) or the ~~newer open-source version [Open Note Block Studio](https://opennbs.org/)~~ (compatability with the newer version is not possible at the moment)

With Note Block Studio you can convert midi versions of your favourite songs to nbs files ans play them in-game

## Command line arguments
```
wave-amp -h

-l                      lists all outputs connected to the computer.
-c <config file>        loads the parameters from a file. parameters are separated by newlines.
-t <theme file>         loads the theme from a file.
-f <filter[:second]>    sets the note filter for the outputs.
examples:
-f 10111                sets the filter for all outputs to remove the bass instrument.
-f 10011:01100          sets the filter so the bass and basedrum instruments only come out of the second output
-v <volume[:second]>    sets the volume for the outputs.
--nrm --stp --rep --shf sets the play mode.
--noui --noinput        disables the ui/keyboard input
--exit                  to reboot the system after a song played
```
