# Alt Command

**Alt Command** is an Ashita v4 addon that allows users to create and manage custom windows and buttons:

![Screenshot](https://github.com/user-attachments/assets/ba388e68-356b-4bbe-a00b-14195d78fafd)

---

## Getting Started

Type `/altc` or `/altcommand` to bring up the main configuration window:

![Screenshot 2024-12-19 150942](https://github.com/user-attachments/assets/5fec47b7-1b91-4aff-92de-3316e64d5ded)

---

## Creating a Window

### Step 1: Select Button Type
Use the radio buttons to select the button type:
 
- **Normal**
  
![Screenshot 2024-12-19 151303](https://github.com/user-attachments/assets/dba8ffee-862c-4a29-863d-59432d0b6116)

- **Image Button**
  
![Screenshot 2024-12-19 151355](https://github.com/user-attachments/assets/50f4e365-a767-4684-805b-3032f9f52fe0)

### Step 2: Configure Window Settings
Use the settings in the left pane to configure:
- **Window Color/Alpha**
- **Button Color/Alpha**
- **Text Color/Alpha** (if applicable)
- **Max Buttons per Row** (determines how many buttons before a new row starts)
- **Button Spacing**
- **Button Size**

You must create a unique name for every window you create. Once configured, click **Create Window**:

![Screenshot 2024-12-19 152700](https://github.com/user-attachments/assets/394b0bb0-0b19-4170-b76f-c1a0aabda4bb)

### Step 3: Position the Window
Windows can be moved by **Shift + Click and Drag** to the desired position. 

You can also move the window via the **Window Settings for:** menu by either clicking and dragging the X and Y position numbers, or double-clicking to manually enter coordinates. 

**Positions are automatically saved.**

---

## Adding Buttons

**Note:** Normal buttons can only be added to normal button windows, and image buttons can only be added to image button windows.

### Step 1: Open Button Configuration
Click the **Add/Edit Buttons** tab at the top of the main window and select the desired window from the dropdown:

![Screenshot 2024-12-19 152506](https://github.com/user-attachments/assets/67489b57-47fe-44c2-8ad5-9bfff4be6828)

### Step 2: Select Command Type
Use the radio buttons to select the command type:

![Command Type Options](https://github.com/user-attachments/assets/0dc4d109-317e-4477-a97e-d0c8f2cdaef6)

### Command Types

#### **Direct Command**
Issues a single command, like a one-line macro. For example:

![Screenshot 2024-12-19 152422](https://github.com/user-attachments/assets/df5c4b10-7ab0-4e84-9344-fd68173cc99c)

If using image buttons, include the path to the icon. Images must be in `/altcommand/resources/your/path/to.png`. If the path is incorrect, a fallback image will be used.

---

#### **Toggle On/Off Command**
Toggles commands with two states, such as `/ms followme` for Multisend:

![Screenshot 2024-12-19 153034](https://github.com/user-attachments/assets/ab013461-b81c-4759-bdcf-3be7a1808454)

Using a normal button for toggle commands will display state-dependent labels. For example:
- **Off State:** ![Screenshot 2024-12-19 153108](https://github.com/user-attachments/assets/0d47bcd0-8e8c-4d9d-a118-d7ca5c51f8da)
- **On State:** ![Screenshot 2024-12-19 153127](https://github.com/user-attachments/assets/6ea246d3-2a7d-4dec-a20a-0c629b6cd293)

This can also be used for any 2 words your command uses to toggle:

![Screenshot 2024-12-19 163533](https://github.com/user-attachments/assets/f0089a0c-85df-445e-97a1-d400b2053a17)

- **Off State:** ![Screenshot 2024-12-19 163600](https://github.com/user-attachments/assets/99b621ca-81bc-41cf-ba40-1f315924c3a9)
- **On State:** ![Screenshot 2024-12-19 163618](https://github.com/user-attachments/assets/6e67746c-61d4-4736-9f6b-aa0867e52e8a)

---

#### **Command Series**
Acts like a multi-line macro with a configurable delay (in 0.1-second increments):

![Screenshot 2024-12-19 164917](https://github.com/user-attachments/assets/3b032d03-01be-4dc2-aec6-03254992cea9)

Each text entry creates a new blank entry below. Leave the final entry blank to signal the end of the series.

---

#### **Window Toggle**
Toggles the visibility of windows:

![Screenshot 2024-12-19 165534](https://github.com/user-attachments/assets/017651bd-c734-4f26-9c69-014af9d51060)

For example:
- Create a window named **Corsair Main**.
- Add a **Shots** toggle button in the Corsair Main window.
- Create another window named **Shots** with all of the Quck Draw elemental shots.
- Clicking the **Shots** button toggles the **Shots** window's visibility. You can further nest windows if desired.

---

## Editing

### Editing Windows
Window settings can be edited after creation, except for the window type (normal or image buttons). Editing options are available below the Add Button section:

![Screenshot 2024-12-19 165928](https://github.com/user-attachments/assets/2549bec5-ff5c-44b5-a4c3-58d0a69008d3)

- A preview of changes is shown in the top-right.
- Click **Save** to apply changes or **Cancel** to revert.
- Windows can also be deleted from here.

---

### Editing Buttons
Click on a button in the preview window to edit it:

![Screenshot 2024-12-19 170241](https://github.com/user-attachments/assets/9084a3bc-8053-403e-9bb9-d25e7c58f30f)

- Buttons can be moved within the current window.
- All button settings can be changed.

---

## Notes

- All windows must have unique names.
- Window positions save automatically.
- Normal buttons cannot be placed in image button windows, and vice versa.

---

## To-Do

- Create additional custom icons.

---

## Acknowledgments

- **atom0s** and **Thorny** for Ashita.
- **at0mos** for figuring out what I was doing wrong with image buttons and correcting my texture loading code.
- **onimitch** for UI hiding code, thanks Mitch!
