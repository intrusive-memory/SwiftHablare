#!/usr/bin/osascript

(*
Download Premium and Enhanced Voices for System Language
=========================================================

This script guides the user through System Settings to download all
Enhanced and Premium voices for their current system language.

Navigation Path:
1. System Settings → Accessibility
2. Accessibility → Read & Speak
3. Read & Speak → System voice info button
4. Voice list → Download all Enhanced/Premium voices for system language

Requirements:
- macOS 26.0+
- User must approve System Events automation when prompted

Usage:
    ./download-premium-voices.applescript

Author: SwiftCompartido
Version: 1.0.0
*)

-- Display welcome message
display dialog "This script will help you download all Enhanced and Premium voices for your system language.

This is useful for SwiftCompartido's Text-to-Speech features.

Click Continue to open System Settings." buttons {"Cancel", "Continue"} default button "Continue" with icon note

if button returned of result is "Cancel" then
	return
end if

-- Open System Settings
tell application "System Settings"
	activate
	delay 1
end tell

-- Navigate to Accessibility → Read & Speak
tell application "System Events"
	tell process "System Settings"
		-- Wait for System Settings to be ready
		repeat until exists
			delay 0.1
		end repeat

		set frontmost to true
		delay 0.5

		-- Click Accessibility in sidebar
		try
			click button "Accessibility" of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window "System Settings"
			delay 1
		on error errMsg
			display dialog "Error: Could not find Accessibility in sidebar. Please navigate to System Settings → Accessibility manually." buttons {"OK"} default button "OK" with icon stop
			return
		end try

		-- Click Read & Speak
		try
			click button "Read & Speak" of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window "System Settings"
			delay 1
		on error errMsg
			display dialog "Error: Could not find 'Read & Speak' button. Please click it manually." buttons {"OK"} default button "OK" with icon stop
			return
		end try

		-- Get current system language
		set systemLanguage to do shell script "defaults read -g AppleLocale | cut -d'_' -f1"

		-- Scroll down to System voice section
		try
			-- Scroll to make System voice visible
			repeat 3 times
				key code 125 -- Down arrow
				delay 0.1
			end repeat
			delay 0.5
		end try

		-- Click the info button next to System voice
		try
			-- Find and click the info button (i) next to System voice
			click button 2 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window "System Settings"
			delay 1.5
		on error errMsg
			display dialog "Error: Could not find System voice info button. Please click the (i) button next to 'System voice' manually." buttons {"OK"} default button "OK" with icon stop
			return
		end try

		-- Now we're in the voice selection sheet
		display dialog "Voice selection panel is now open.

Look for your system language section (e.g., 'English (United States)').

Click the download buttons (cloud icons) next to:
• All voices marked '(Enhanced)'
• All voices marked '(Premium)'

This ensures SwiftCompartido has access to the highest quality voices.

Click 'I'm Done' when you've downloaded all voices, or 'Download Automatically' to attempt automatic download." buttons {"Cancel", "Download Automatically", "I'm Done"} default button "Download Automatically" with icon note

		set userChoice to button returned of result

		if userChoice is "Cancel" then
			-- Close the sheet
			try
				click button "Done" of sheet 1 of window "System Settings"
			end try
			return
		else if userChoice is "Download Automatically" then
			-- Attempt to download all Enhanced and Premium voices
			try
				-- Get the language section header
				set languageHeader to ""

				-- Try to find language-specific voices and download them
				-- This is challenging because the UI hierarchy varies by language

				-- Get all download buttons in the sheet
				set downloadButtons to buttons of scroll area 1 of sheet 1 of window "System Settings"
				set downloadCount to 0

				repeat with btn in downloadButtons
					try
						-- Check if button has a download icon (cloud with down arrow)
						if description of btn contains "download" or title of btn contains "download" then
							-- Get the row to check if it's Enhanced or Premium
							set parentRow to (a reference to (parent of parent of btn))
							set rowText to value of static text of parentRow as string

							if rowText contains "Enhanced" or rowText contains "Premium" then
								click btn
								set downloadCount to downloadCount + 1
								delay 0.5 -- Wait for download to start
							end if
						end if
					end try
				end repeat

				if downloadCount > 0 then
					display dialog "Started downloading " & downloadCount & " voice(s).

Downloads will continue in the background. You can monitor progress in the Voice panel.

Click OK to close System Settings." buttons {"OK"} default button "OK" with icon note
				else
					display dialog "No Enhanced or Premium voices found to download.

Possible reasons:
• All voices are already downloaded
• Your language doesn't have Premium voices yet
• Unable to detect download buttons automatically

Please download manually if needed." buttons {"OK"} default button "OK" with icon caution
				end if

			on error errMsg
				display dialog "Automatic download failed: " & errMsg & "

Please download voices manually:
1. Look for your language section
2. Click cloud icons next to Enhanced/Premium voices
3. Click Done when finished

Downloads continue in background." buttons {"OK"} default button "OK" with icon caution
			end try
		end if

		-- Wait for user to finish or close
		delay 2

		-- Close the voice selection sheet if it's still open
		try
			if exists button "Done" of sheet 1 of window "System Settings" then
				click button "Done" of sheet 1 of window "System Settings"
			end if
		end try

	end tell
end tell

-- Final message
display dialog "Voice download process complete!

Enhanced and Premium voices provide the best quality for SwiftCompartido's Text-to-Speech features.

Downloads continue in the background if still in progress." buttons {"OK"} default button "OK" with icon note

-- Return to the app that called this script
tell application "System Events"
	set frontProcess to first process whose frontmost is true
	if name of frontProcess is "System Settings" then
		-- If still in System Settings, go back to previous app
		tell application "System Events" to keystroke tab using command down
	end if
end tell
