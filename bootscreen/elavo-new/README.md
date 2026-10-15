# Elavo boot

Plymouth theme for the Elavo boot splash. The theme directory is `elavo-boot`. Installed, that directory is `/usr/share/plymouth/themes/elavo-boot`, and the theme name passed to `plymouth-set-default-theme` is `elavo-boot`.

Boot shows the sun (`logo.png`) and a progress bar on a black background. Shutdown and reboot show only the black background. Suspend and resume use `suspend.png`. A password prompt takes the progress bar's place, and the bar hides until the password is accepted. The prompt is a white pill at 75% opacity (`entry.png`) with a black lock (`lock.png`) inside it, and a black dot (`bullet.png`) for each typed character. Its size follows the screen width. Above it the theme always shows "Enter your password to unlock this disk", not the prompt text systemd sends. Status messages are not shown.

![Elavo boot](preview.png)

The script and layout started from the Plymouth theme by Lozano Juan Pablo (libredeb@gmail.com). This copy is adapted for Elavo. It is GPL-2.0-only. See [LICENSE](LICENSE).
