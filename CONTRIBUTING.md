# Contributing

> ⚠️ If you're not already a team member, please contact roda2324#9206 on Discord before doing anything.

## Table of contents

- [Table of contents](#table-of-contents)
- [1. Setting everything up (you only need to do this once)](#1-setting-everything-up-you-only-need-to-do-this-once)
  - [1.1. GitHub](#11-github)
  - [1.2. Visual Studio Code](#12-visual-studio-code)
  - [1.3. Git](#13-git)
  - [1.4. Clone the repository](#14-clone-the-repository)
- [2. Modding and working as a team](#2-modding-and-working-as-a-team)
  - [2.1. Creating a branch](#21-creating-a-branch)
  - [2.2. Modding and committing changes](#22-modding-and-committing-changes)
    - [2.2.1. Modding](#221-modding)
    - [2.2.2. Committing changes](#222-committing-changes)
    - [2.2.3. Pushing changes](#223-pushing-changes)
    - [2.2.4. Merging your branch with the main project**](#224-merging-your-branch-with-the-main-project)
  - [2.3. Updating your local copy](#23-updating-your-local-copy)
    - [Updating your local branch](#updating-your-local-branch)
    - [Updating your local main branch](#updating-your-local-main-branch)
  - [2.4. Viewing the history of changes](#24-viewing-the-history-of-changes)

## 1. Setting everything up (you only need to do this once)

### 1.1. GitHub

- Create a GitHub account: <https://github.com/signup>
- Tell me your GitHub username so I can add you as a collaborator.

### 1.2. Visual Studio Code

- Download and install Visual Studio Code: <https://code.visualstudio.com/>
- Run it, press `Ctrl-Shift-X` and install the following extensions (use the search bar):
  - Git Blame
  - Git History

### 1.3. Git

- Download and install Git: <https://git-scm.com/downloads> (use the default options, but make sure to select Visual Studio Code as the default editor).
- Go back to Visual Studio Code, click on `Terminal` and then `New Terminal`.
- Type `git config --global user.name "Your Name"` (don't remove the quotes) and press `Enter`.
- Type `git config --global user.email "youremail@example.com"` (don't remove the quotes) and press `Enter`.

### 1.4. Clone the repository

- Still in VSCode's Terminal, type `cd "C:\Users\Your Name\Games\Age of Empires 3 DE\XXXXXXXXXXXXXXXXX\mods\local"` and Press `Enter`.
- Type `code .` and press `Enter`. A new window should open. You can close the old one.
- In the new window, click on `Terminal` and then `New Terminal`.
- Type `git clone https://github.com/thinotmandresy/age-of-pirates.git` and press `Enter`. A new folder called `age-of-pirates` should appear in the "local" folder.
- Type `cd age-of-pirates` and press `Enter`.
- Type `code .` and press `Enter`. A new window should open. You can close the old one.
  - Alternatively, you can open the `age-of-pirates` folder in Visual Studio Code by clicking on `File` and then `Open Folder...`.

Congratulations, you're ready to start modding!

## 2. Modding and working as a team

### 2.1. Creating a branch

To avoid conflicts, each team member will work on their own branch. Basically, a branch is like a copy of the main project, and when you modify something in your branch, it doesn't affect the main project. When you're sure that your changes are ready, you can merge your branch with the main project.

- With the `age-of-pirates` folder open in Visual Studio Code, you should see a tiny icon on the bottom left corner that says `main` (it's quite small, lol). Click on it and select `Create new branch...`.
- Type your name and press `Enter`. A new branch should be created and you should see your name instead of `main` now.
- **IMPORTANT**: Every time you're modding, that little icon should be the very first thing you look at. If it doesn't say your name, click on it and select your branch.

### 2.2. Modding and committing changes

#### 2.2.1. Modding

- Open the `age-of-pirates` folder in Visual Studio Code.
- Make your changes.

#### 2.2.2. Committing changes

A "commit" is basically a save point (like when you play a game and you save your progress). A commit should group one or multiple changes that are related to each other. For example, if you've added a few new maps, you should add these maps in a single commit saying something like "Added X new maps" or something like that. It helps to keep things organized and can be used as a very detailed changelog (among other very useful things).

- Press `Ctrl-Shift-G` (or click on the Git icon on the left side of the screen).
- You should see a list of files that you've modified. Click on the `+` icon next to the files that you want to add to the commit (you can also click on the `+` icon at the top to add all the files at once).
- **IMPORTANT**: Make sure that you only add the files that are used by the game. Photoshop's PSD files, for example, should not be added to the commit. Same thing for TGA and FBX files or any other file that is useful for *you* but not for the game or the other team members.
- Type a commit message (something like "Added X new maps") and click `Commit` (the checkmark icon).

#### 2.2.3. Pushing changes

A commit is only saved locally on your computer. To save it on GitHub, you need to push it.

- Press `Ctrl-Shift-G` (or click on the Git icon on the left side of the screen).
- Click on the 3 dots icon at the top and select `Push`.

You will probably be asked to log in to your GitHub account. Do it and wait for the push to finish.

#### 2.2.4. Merging your branch with the main project**

Once you're sure that your changes are ready, you can merge your branch with the main project. This will add your changes to the main project.

- Go to the repository page on GitHub: <https://github.com/thinotmandresy/age-of-pirates>
- Click on `Pull requests` and then `New pull request`.
- Select your branch and click on `Create pull request`.
- Type a title and a description for your pull request and click on `Create pull request` again. For example, if your commits are mostly about fixing bugs, you can write something like "Fixed X bugs" and add more information in the description.
- Ping me and I will merge your branch with the main project.

### 2.3. Updating your local copy

If you want to update your local copy with the latest changes from the main project, you need to pull the changes.

#### Updating your local branch

- Open the `age-of-pirates` folder in Visual Studio Code.
- Switch to your branch.
- Click on `Terminal` and then `New Terminal`.
- Type `git pull origin main` and press `Enter`.
- Type `git push` and press `Enter`.

#### Updating your local main branch

- Open the `age-of-pirates` folder in Visual Studio Code.
- Switch to the main branch.
- Click on `Terminal` and then `New Terminal`.
- Type `git pull` and press `Enter`.

### 2.4. Viewing the history of changes

- Open the `age-of-pirates` folder in Visual Studio Code.
- Press `Ctrl-Shift-G` (or click on the Git icon on the left side of the screen).
- Click on the history icon at the top (the clock icon).

![Git history icon](/docs/assets/git-history-icon.png)

- You can click on any commit to see the files that were added/modified/removed in that commit.

![Git history](/docs/assets/git-history.png)

- Next to each file, you can click on the `Previous` button to see the differences from the previous commit.

![Commit diff](/docs/assets/commit-diff.png)
