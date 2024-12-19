# Alt Command

**Alt Command** is an Ashita v4 addon that allows users to create and manage custom windows and buttons.

Most of the screenshots here are slightly outdated. The window and button borders have been removed, slight rounding has been added, and there is now an option to manually position windows from within the UI. I'll update the README with new visuals when I have more time.

The picture below is a more accurate representation of what the addon produces. More custom icons will be added over time as I create them:

![Screenshot](https://github.com/user-attachments/assets/ba388e68-356b-4bbe-a00b-14195d78fafd)

---

## Getting Started

Type `/altc` or `/altcommand` to bring up the main configuration window:

![Main Configuration Window](https://github.com/user-attachments/assets/9a2ecedb-85e8-4e11-95fe-839ffb0eef47)

---

## Creating a Window

### Step 1: Select Button Type
Use the radio buttons to select the button type:

![Normal Button](https://github.com/user-attachments/assets/ed3c76b8-ebe8-4a97-9e99-2c41466f6723) or ![Image Button](https://github.com/user-attachments/assets/aa608f63-4678-4790-8fdd-f7dda089a3fb)

### Step 2: Configure Window Settings
Use the settings in the left pane to configure:
- **Window Color/Alpha**
- **Button Color/Alpha**
- **Text Color/Alpha** (if applicable)
- **Max Buttons per Row** (determines how many buttons before a new row starts)
- **Button Spacing**
- **Button Size**

You must create a unique name for every window you create. Once configured, click **Create Window**:

![Create Window Settings](https://github.com/user-attachments/assets/8c975396-df4b-4cef-8954-f082acb5db51)

### Step 3: Position the Window
Windows can be moved by **Shift + Click and Drag** to the desired position. 

You can also move the window via the **Window Settings for:** menu by either clicking and dragging the X and Y position numbers, or double-clicking to manually enter coordinates. 

**Positions are automatically saved.**

---

## Adding Buttons

**Note:** Normal buttons can only be added to normal button windows, and image buttons can only be added to image button windows.

### Step 1: Open Button Configuration
Click the **Add/Edit Buttons** tab at the top of the main window and select the desired window from the dropdown:

![Add/Edit Buttons Tab](https://github.com/user-attachments/assets/1c8eba53-d2af-4220-8841-434907056999)

### Step 2: Select Command Type
Use the radio buttons to select the command type:

![Command Type Options](https://github.com/user-attachments/assets/0dc4d109-317e-4477-a97e-d0c8f2cdaef6)

### Command Types

#### **Direct Command**
Issues a single command, like a one-line macro. For example:

![Direct Command Example](https://github.com/user-attachments/assets/9e825946-561b-4c1c-b1cb-ab68a6141d68)

If using image buttons, include the path to the icon. Images must be in `/altcommand/resources/your/path/to.png`. If the path is incorrect, a fallback image will be used.

---

#### **Toggle On/Off Command**
Toggles commands with two states, such as `/ms followme` for Multisend:

![Toggle Command Example](https://github.com/user-attachments/assets/6f043e17-44fc-4599-be35-7fd547e83525)

Using a normal button for toggle commands will display state-dependent labels. For example:
- **Off State:** ![Off State](https://github.com/user-attachments/assets/7887a4f5-87cf-42b3-bf2e-40633d744080)
- **On State:** ![On State](https://github.com/user-attachments/assets/96ded6ec-4648-4035-a37c-96766e5bc724)

---

#### **Command Series**
Acts like a multi-line macro with a configurable delay (in 0.1-second increments):

![Command Series Example](https://github.com/user-attachments/assets/edcf9867-cb52-48dd-9564-3f4e0f551395)

Each text entry creates a new blank entry below. Leave the final entry blank to signal the end of the series.

---

#### **Window Toggle**
Toggles the visibility of windows with the same name as the command:

![Window Toggle Example](https://github.com/user-attachments/assets/31ecf945-7625-4a0e-95a9-5c27517c8804)

For example:
- Create a window named **Jobs**.
- Add a **Corsair** toggle button in the Jobs window.
- Create another window named **Corsair** with specific buttons for that job.
- Clicking the Corsair button toggles the Corsair window's visibility. You can further nest windows (e.g., Rolls, Quick Draw) within the Corsair window.

---

## Editing

### Editing Windows
Window settings can be edited after creation, except for the window type (normal or image buttons). Editing options are available below the Add Button section:

![Edit Window Options](https://github.com/user-attachments/assets/ea8ae00c-358d-4630-8823-f70ee7a43e77)

- A preview of changes is shown in the top-right.
- Click **Save** to apply changes or **Cancel** to revert.
- Windows can also be deleted from here.

---

### Editing Buttons
Click on a button in the preview window to edit it:

![Edit Button Example](https://github.com/user-attachments/assets/6ad67af3-9bad-4871-bccd-ba44fa563ac8)

- Buttons can be moved within the current window.
- All button settings can be changed.

---

## Notes

- All windows must have unique names.
- Window positions save automatically.
- Normal buttons cannot be placed in image button windows, and vice versa.

---

## To-Do

- ~~Add saving and loading of window sets per job.~~ Done
- Create additional custom icons.

---

## Acknowledgments

- **atom0s** and **Thorny** for Ashita.
- **at0mos** for figuring out what I was doing wrong with image buttons and correcting my texture loading code.
- **onimitch** for UI hiding code, thanks Mitch!
