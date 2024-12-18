# Alt Command

### Alt Command is an Ashita v4 addon that allows users to create and manage custom windows and buttons.

Most of the screenshots here are a little outdated, the window and button borders have been removed and slight rounding has been added, as well as the option to manually position windows from within the UI. I'll update the README when I have more time. the picture below is a more accurate representation of what the addon will produce. More custom icons will be added over time, as I have time to create them.

![Screenshot 2024-12-18 094239](https://github.com/user-attachments/assets/ba388e68-356b-4bbe-a00b-14195d78fafd)

# Getting Started

Type /altc or /altcommand to bring up the main configuration window:

![Screenshot 2024-12-13 133413](https://github.com/user-attachments/assets/9a2ecedb-85e8-4e11-95fe-839ffb0eef47)

## Create A Window

Use the radio buttons to select button type:

![Screenshot 2024-12-13 135813](https://github.com/user-attachments/assets/ed3c76b8-ebe8-4a97-9e99-2c41466f6723)   or   ![Screenshot 2024-12-13 135834](https://github.com/user-attachments/assets/aa608f63-4678-4790-8fdd-f7dda089a3fb)

Use the settings in the left pane to select window color/alpha, button color/alpha, text color/alpha (if applicable,) max buttons per row (determines how man buttons before we start a new row,) button spacing, and button size. You must create a unique name for every window you create, then click create window.

![Screenshot 2024-12-13 133507](https://github.com/user-attachments/assets/8c975396-df4b-4cef-8954-f082acb5db51)

Windows can be moved by shift-click and drag to desired position, and automatically save position to settings when done dragging.

## Add Some Buttons
### Note: Normal buttons can only go in normal button windows, image buttons can only go in image button windows.

Click the Add/Edit Buttons tab at the top of the main window (and select desired window frim the dropdown):

![Screenshot 2024-12-13 181808](https://github.com/user-attachments/assets/1c8eba53-d2af-4220-8841-434907056999)

Use the Command Type radio to select what kind of command you will be creating:

![Screenshot 2024-12-13 182257](https://github.com/user-attachments/assets/0dc4d109-317e-4477-a97e-d0c8f2cdaef6)

## Direct Command issues a single command, like a one line macro. Here's an example:

![Screenshot 2024-12-13 182239](https://github.com/user-attachments/assets/9e825946-561b-4c1c-b1cb-ab68a6141d68)

I'm using Image Buttons for this demo, so I included the path to the icon I want to use for that command. Alt Command expects all images the be in /altcommand/resources/your/path/to.png. 
If the path is incorrect a fallback image will be used instead.

## Toggle On/Off commands are for toggling any commands that have 2 states, such as /ms followme for Multisend:

![Screenshot 2024-12-13 183815](https://github.com/user-attachments/assets/6f043e17-44fc-4599-be35-7fd547e83525)

I used a normal button for this command. When using normal buttons for toggle commands, they will change display depending on the current state. Since I used Follow, when off it will display ![Screenshot 2024-12-13 184138](https://github.com/user-attachments/assets/7887a4f5-87cf-42b3-bf2e-40633d744080), and when on it will display ![Screenshot 2024-12-13 184211](https://github.com/user-attachments/assets/96ded6ec-4648-4035-a37c-96766e5bc724).

## Command Series acts like a multi-line macro, with a configurable delay between steps (0.1 second incriments):

![Screenshot 2024-12-13 185228](https://github.com/user-attachments/assets/edcf9867-cb52-48dd-9564-3f4e0f551395)

Each text entry in a command series creates a new blank entry below it. Leave the final entry blank to signal the end of the series.

## Window Toggles are used to toggle visibility of windows with the same name as the command:

![Screenshot 2024-12-13 190456](https://github.com/user-attachments/assets/31ecf945-7625-4a0e-95a9-5c27517c8804)

For this example I created a window named Jobs, and created a window toggle button called Corsair. Now, I can create a window called Corsair, and fill it with buttons I only use for as COR. Clicking the Corsair button on the Jobs window, will toggle visibility of the Corsair window. You could further nest more windows inside the Corsair window if you wished, such as Rolls, or Quck Draw, etc. to provide access to commands when needed, but hide them when not in use.

# Editing
All windows scale with button settings and can be edited after creation except window type (normal or image buttons.)

## Editing Windows:
Window editing for the currently selected window is available below the add button section:

![Screenshot 2024-12-13 192356](https://github.com/user-attachments/assets/ea8ae00c-358d-4630-8823-f70ee7a43e77)

A preview of the changes will be shown on the top right. Click Save to retain changes, or cancel to revert. Windows can be deleted entirely from here as well.

## Editing Buttons:
Click on a button in the preview window to edit it.

![Screenshot 2024-12-13 193416](https://github.com/user-attachments/assets/6ad67af3-9bad-4871-bccd-ba44fa563ac8)

Buttons can be moved within the current window, and all button settings can be changed.

# Notes

All buttons and windows must have unique names.

Window positions save automatically after dragging.

Standard buttons cannot be placed on image button windows, and vice versa.

# Thanks

Thanks to atom0s and Thorny for Ashita.

Thanks to at0mos for figuring out what I was doing wrong with image buttons, and correcting my texture loading code.

Thanks to onimitch for the UI hiding sections of code.
