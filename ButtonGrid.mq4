//+------------------------------------------------------------------+
//|                                                   ButtonGrid.mq4 |
//|                              Custom Button Grid Indicator        |
//|                         28 rows x 3 columns (H1, H4, D1)         |
//|                    + Notes, Timeframe Display, Local Clock       |
//+------------------------------------------------------------------+
#property copyright "Custom Indicator"
#property link      ""
#property version   "2.01"
#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| POSITION PARAMETERS - Adjust these to move the button grid       |
//+------------------------------------------------------------------+
input int    InpOffsetX        = 10;        // X Offset (pixels from left)
input int    InpOffsetY        = 50;        // Y Offset (pixels from top)

//+------------------------------------------------------------------+
//| SIZE PARAMETERS - Adjust button dimensions and spacing           |
//+------------------------------------------------------------------+
input int    InpButtonWidth    = 18;        // Button Width (pixels)
input int    InpButtonHeight   = 18;        // Button Height (pixels)
input int    InpButtonSpacingX = 2;         // Horizontal spacing between buttons
input int    InpButtonSpacingY = 2;         // Vertical spacing between buttons
input int    InpHeaderHeight   = 20;        // Header row height

//+------------------------------------------------------------------+
//| NOTE PARAMETERS - Editable text next to each row                  |
//+------------------------------------------------------------------+
input int    InpNoteWidth      = 60;        // Note Field Width (pixels)
input int    InpNoteSpacing    = 5;         // Space between buttons and note
input color  InpNoteTextColor  = clrWhite;  // Note Text Color
input int    InpNoteFontSize   = 8;         // Note Font Size

//+------------------------------------------------------------------+
//| TIMEFRAME & SYMBOL DISPLAY PARAMETERS                             |
//+------------------------------------------------------------------+
input int    InpTFDisplayX     = 200;       // Timeframe Display X Position
input int    InpTFDisplayY     = 30;        // Timeframe Display Y Position
input color  InpTFDisplayColor = clrYellow; // Timeframe Display Color
input int    InpTFDisplaySize  = 20;        // Timeframe Display Font Size

//+------------------------------------------------------------------+
//| CLOCK PARAMETERS                                                  |
//+------------------------------------------------------------------+
input int    InpClockX         = 500;       // Clock X Position
input int    InpClockY         = 30;        // Clock Y Position
input color  InpClockColor     = clrYellow; // Clock Color
input int    InpClockFontSize  = 16;        // Clock Font Size

//+------------------------------------------------------------------+
//| COLOR PARAMETERS - Customize all colors from Inputs tab          |
//+------------------------------------------------------------------+
input color  InpColorGray      = clrDimGray;     // Button Color: Gray (default)
input color  InpColorGreen     = clrLime;        // Button Color: Green (1st click)
input color  InpColorRed       = clrRed;         // Button Color: Red (2nd click)
input color  InpColorBorder    = clrGray;        // Button Border Color
input color  InpHeaderTextColor= clrYellow;      // Header Text Color (H1/H4/D1)
input int    InpHeaderFontSize = 8;              // Header Font Size
input color  InpBackgroundColor= clrBlack;       // Background Panel Color
input int    InpBackgroundPadding = 5;           // Background Padding (pixels)

//+------------------------------------------------------------------+
//| PERSISTENCE PARAMETERS                                            |
//+------------------------------------------------------------------+
input string InpStateFileName  = "ButtonGridState";  // State File Name (without extension)

//+------------------------------------------------------------------+
//| GRID CONFIGURATION                                                |
//+------------------------------------------------------------------+
#define ROWS 28
#define COLS 3

// Button state: 0=Gray, 1=Green, 2=Red
int ButtonState[ROWS][COLS];

// Note text for each row
string NoteText[ROWS];

// Object name prefix
string PREFIX = "BtnGrid_";

// Column headers
string ColHeaders[COLS] = {"H1", "H4", "D1"};

// State file path
string StateFilePath;
string NotesFilePath;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Build state file paths (saved in MQL4/Files folder)
   StateFilePath = InpStateFileName + ".dat";
   NotesFilePath = InpStateFileName + "_notes.txt";

   // Initialize all buttons to gray state (0) and notes to empty
   for(int row = 0; row < ROWS; row++)
   {
      NoteText[row] = "";
      for(int col = 0; col < COLS; col++)
      {
         ButtonState[row][col] = 0;
      }
   }

   // Load saved states from file (if exists)
   LoadButtonStates();
   LoadNotes();

   // Enable chart events for click detection
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   // Set timer for clock updates (every second)
   EventSetTimer(1);

   // Create all UI elements
   CreateButtonGrid();
   CreateTimeframeDisplay();
   CreateClockDisplay();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Kill timer
   EventKillTimer();

   // Save button states and notes before removing indicator
   SaveButtonStates();
   SaveNotes();

   // Remove all objects created by this indicator
   ObjectsDeleteAll(0, PREFIX);
}

//+------------------------------------------------------------------+
//| Timer function - updates clock every second                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateClockDisplay();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   return(rates_total);
}

//+------------------------------------------------------------------+
//| ChartEvent function - handles mouse clicks and text edits         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Check for mouse click on object
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Check if clicked object is one of our buttons
      if(StringFind(sparam, PREFIX + "Btn_") == 0)
      {
         // Parse row and column from object name
         string namePart = StringSubstr(sparam, StringLen(PREFIX + "Btn_"));
         int underscorePos = StringFind(namePart, "_");

         if(underscorePos > 0)
         {
            int row = (int)StringToInteger(StringSubstr(namePart, 0, underscorePos));
            int col = (int)StringToInteger(StringSubstr(namePart, underscorePos + 1));

            if(row >= 0 && row < ROWS && col >= 0 && col < COLS)
            {
               // Cycle to next state: 0->1->2->0
               ButtonState[row][col] = (ButtonState[row][col] + 1) % 3;

               // Update button color
               UpdateButtonColor(row, col);

               // Save states immediately after each click
               SaveButtonStates();
            }
         }
      }
   }

   // Check for edit box text change
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(StringFind(sparam, PREFIX + "Note_") == 0)
      {
         // Parse row from object name
         string rowStr = StringSubstr(sparam, StringLen(PREFIX + "Note_"));
         int row = (int)StringToInteger(rowStr);

         if(row >= 0 && row < ROWS)
         {
            // Get the new text
            NoteText[row] = ObjectGetString(0, sparam, OBJPROP_TEXT);
            // Save notes
            SaveNotes();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Save button states to file                                        |
//+------------------------------------------------------------------+
void SaveButtonStates()
{
   int fileHandle = FileOpen(StateFilePath, FILE_WRITE|FILE_BIN);

   if(fileHandle != INVALID_HANDLE)
   {
      // Write all button states
      for(int row = 0; row < ROWS; row++)
      {
         for(int col = 0; col < COLS; col++)
         {
            FileWriteInteger(fileHandle, ButtonState[row][col], CHAR_VALUE);
         }
      }
      FileClose(fileHandle);
   }
   else
   {
      Print("ButtonGrid: Failed to save states to file: ", StateFilePath);
   }
}

//+------------------------------------------------------------------+
//| Load button states from file                                      |
//+------------------------------------------------------------------+
void LoadButtonStates()
{
   if(!FileIsExist(StateFilePath))
   {
      Print("ButtonGrid: No saved state file found, starting fresh.");
      return;
   }

   int fileHandle = FileOpen(StateFilePath, FILE_READ|FILE_BIN);

   if(fileHandle != INVALID_HANDLE)
   {
      // Read all button states
      for(int row = 0; row < ROWS; row++)
      {
         for(int col = 0; col < COLS; col++)
         {
            if(!FileIsEnding(fileHandle))
            {
               int state = FileReadInteger(fileHandle, CHAR_VALUE);
               // Validate state (0, 1, or 2)
               if(state >= 0 && state <= 2)
               {
                  ButtonState[row][col] = state;
               }
            }
         }
      }
      FileClose(fileHandle);
      Print("ButtonGrid: States loaded successfully from file.");
   }
   else
   {
      Print("ButtonGrid: Failed to load states from file: ", StateFilePath);
   }
}

//+------------------------------------------------------------------+
//| Save notes to file                                                |
//+------------------------------------------------------------------+
void SaveNotes()
{
   int fileHandle = FileOpen(NotesFilePath, FILE_WRITE|FILE_TXT);

   if(fileHandle != INVALID_HANDLE)
   {
      for(int row = 0; row < ROWS; row++)
      {
         FileWriteString(fileHandle, NoteText[row] + "\n");
      }
      FileClose(fileHandle);
   }
   else
   {
      Print("ButtonGrid: Failed to save notes to file: ", NotesFilePath);
   }
}

//+------------------------------------------------------------------+
//| Load notes from file                                              |
//+------------------------------------------------------------------+
void LoadNotes()
{
   if(!FileIsExist(NotesFilePath))
   {
      Print("ButtonGrid: No saved notes file found.");
      return;
   }

   int fileHandle = FileOpen(NotesFilePath, FILE_READ|FILE_TXT);

   if(fileHandle != INVALID_HANDLE)
   {
      for(int row = 0; row < ROWS; row++)
      {
         if(!FileIsEnding(fileHandle))
         {
            string line = FileReadString(fileHandle);
            // Remove trailing newline if present
            StringReplace(line, "\n", "");
            StringReplace(line, "\r", "");
            NoteText[row] = line;
         }
      }
      FileClose(fileHandle);
      Print("ButtonGrid: Notes loaded successfully from file.");
   }
   else
   {
      Print("ButtonGrid: Failed to load notes from file: ", NotesFilePath);
   }
}

//+------------------------------------------------------------------+
//| Get timeframe string                                              |
//+------------------------------------------------------------------+
string GetTimeframeString()
{
   switch(Period())
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "??";
   }
}

//+------------------------------------------------------------------+
//| Create timeframe and symbol display                               |
//+------------------------------------------------------------------+
void CreateTimeframeDisplay()
{
   string tfName = PREFIX + "TFDisplay";
   string displayText = GetTimeframeString() + " " + Symbol();

   ObjectCreate(0, tfName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, tfName, OBJPROP_XDISTANCE, InpTFDisplayX);
   ObjectSetInteger(0, tfName, OBJPROP_YDISTANCE, InpTFDisplayY);
   ObjectSetInteger(0, tfName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, tfName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetString(0, tfName, OBJPROP_TEXT, displayText);
   ObjectSetString(0, tfName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, tfName, OBJPROP_FONTSIZE, InpTFDisplaySize);
   ObjectSetInteger(0, tfName, OBJPROP_COLOR, InpTFDisplayColor);
   ObjectSetInteger(0, tfName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create clock display                                              |
//+------------------------------------------------------------------+
void CreateClockDisplay()
{
   string clockName = PREFIX + "Clock";

   ObjectCreate(0, clockName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, clockName, OBJPROP_XDISTANCE, InpClockX);
   ObjectSetInteger(0, clockName, OBJPROP_YDISTANCE, InpClockY);
   ObjectSetInteger(0, clockName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, clockName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetString(0, clockName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, clockName, OBJPROP_FONTSIZE, InpClockFontSize);
   ObjectSetInteger(0, clockName, OBJPROP_COLOR, InpClockColor);
   ObjectSetInteger(0, clockName, OBJPROP_SELECTABLE, false);

   // Set initial time
   UpdateClockDisplay();
}

//+------------------------------------------------------------------+
//| Update clock display                                              |
//+------------------------------------------------------------------+
void UpdateClockDisplay()
{
   string clockName = PREFIX + "Clock";
   datetime localTime = TimeLocal();
   string timeStr = TimeToString(localTime, TIME_SECONDS);

   ObjectSetString(0, clockName, OBJPROP_TEXT, timeStr);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create the entire button grid                                     |
//+------------------------------------------------------------------+
void CreateButtonGrid()
{
   // Create background panel first (so it's behind everything)
   CreateBackgroundPanel();

   // Create "Note" header
   string noteHeaderName = PREFIX + "NoteHeader";
   int noteHeaderX = InpOffsetX + COLS * (InpButtonWidth + InpButtonSpacingX) + InpNoteSpacing;
   int noteHeaderY = InpOffsetY;

   ObjectCreate(0, noteHeaderName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, noteHeaderName, OBJPROP_XDISTANCE, noteHeaderX);
   ObjectSetInteger(0, noteHeaderName, OBJPROP_YDISTANCE, noteHeaderY);
   ObjectSetInteger(0, noteHeaderName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, noteHeaderName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetString(0, noteHeaderName, OBJPROP_TEXT, "Note");
   ObjectSetString(0, noteHeaderName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, noteHeaderName, OBJPROP_FONTSIZE, InpHeaderFontSize);
   ObjectSetInteger(0, noteHeaderName, OBJPROP_COLOR, InpHeaderTextColor);
   ObjectSetInteger(0, noteHeaderName, OBJPROP_SELECTABLE, false);

   // Create header labels (H1, H4, D1)
   for(int col = 0; col < COLS; col++)
   {
      string headerName = PREFIX + "Header_" + IntegerToString(col);
      int headerX = InpOffsetX + col * (InpButtonWidth + InpButtonSpacingX) + InpButtonWidth/2;
      int headerY = InpOffsetY;

      ObjectCreate(0, headerName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, headerName, OBJPROP_XDISTANCE, headerX);
      ObjectSetInteger(0, headerName, OBJPROP_YDISTANCE, headerY);
      ObjectSetInteger(0, headerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, headerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetString(0, headerName, OBJPROP_TEXT, ColHeaders[col]);
      ObjectSetString(0, headerName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, headerName, OBJPROP_FONTSIZE, InpHeaderFontSize);
      ObjectSetInteger(0, headerName, OBJPROP_COLOR, InpHeaderTextColor);
      ObjectSetInteger(0, headerName, OBJPROP_SELECTABLE, false);
   }

   // Create button grid and note fields
   for(int row = 0; row < ROWS; row++)
   {
      // Create buttons for this row
      for(int col = 0; col < COLS; col++)
      {
         CreateButton(row, col);
      }

      // Create note edit field for this row
      CreateNoteField(row);
   }
}

//+------------------------------------------------------------------+
//| Create background panel behind the button grid                    |
//+------------------------------------------------------------------+
void CreateBackgroundPanel()
{
   string bgName = PREFIX + "Background";

   // Calculate panel dimensions (including note fields)
   int panelWidth = COLS * (InpButtonWidth + InpButtonSpacingX) - InpButtonSpacingX + InpNoteSpacing + InpNoteWidth + (InpBackgroundPadding * 2);
   int panelHeight = InpHeaderHeight + ROWS * (InpButtonHeight + InpButtonSpacingY) - InpButtonSpacingY + (InpBackgroundPadding * 2);

   // Panel position (offset by padding)
   int panelX = InpOffsetX - InpBackgroundPadding;
   int panelY = InpOffsetY - InpBackgroundPadding;

   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, InpBackgroundColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, InpBackgroundColor);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 0);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bgName, OBJPROP_ZORDER, 0);  // Behind buttons
}

//+------------------------------------------------------------------+
//| Create a single button at specified row/col                       |
//+------------------------------------------------------------------+
void CreateButton(int row, int col)
{
   string btnName = PREFIX + "Btn_" + IntegerToString(row) + "_" + IntegerToString(col);

   // Calculate button position
   int btnX = InpOffsetX + col * (InpButtonWidth + InpButtonSpacingX);
   int btnY = InpOffsetY + InpHeaderHeight + row * (InpButtonHeight + InpButtonSpacingY);

   // Create button as rectangle label (clickable)
   ObjectCreate(0, btnName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, btnX);
   ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0, btnName, OBJPROP_XSIZE, InpButtonWidth);
   ObjectSetInteger(0, btnName, OBJPROP_YSIZE, InpButtonHeight);
   ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, GetButtonColor(row, col));
   ObjectSetInteger(0, btnName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, InpColorBorder);
   ObjectSetInteger(0, btnName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, btnName, OBJPROP_BACK, false);
   ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, btnName, OBJPROP_ZORDER, 1);
}

//+------------------------------------------------------------------+
//| Create note edit field for a row                                  |
//+------------------------------------------------------------------+
void CreateNoteField(int row)
{
   string noteName = PREFIX + "Note_" + IntegerToString(row);

   // Calculate position (to the right of the buttons)
   int noteX = InpOffsetX + COLS * (InpButtonWidth + InpButtonSpacingX) + InpNoteSpacing;
   int noteY = InpOffsetY + InpHeaderHeight + row * (InpButtonHeight + InpButtonSpacingY);

   // Create editable text field
   ObjectCreate(0, noteName, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, noteName, OBJPROP_XDISTANCE, noteX);
   ObjectSetInteger(0, noteName, OBJPROP_YDISTANCE, noteY);
   ObjectSetInteger(0, noteName, OBJPROP_XSIZE, InpNoteWidth);
   ObjectSetInteger(0, noteName, OBJPROP_YSIZE, InpButtonHeight);
   ObjectSetInteger(0, noteName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, noteName, OBJPROP_BGCOLOR, InpBackgroundColor);
   ObjectSetInteger(0, noteName, OBJPROP_BORDER_COLOR, InpBackgroundColor);  // No visible border
   ObjectSetInteger(0, noteName, OBJPROP_COLOR, InpNoteTextColor);
   ObjectSetString(0, noteName, OBJPROP_FONT, "Arial");  // Arial Regular
   ObjectSetInteger(0, noteName, OBJPROP_FONTSIZE, InpNoteFontSize);
   ObjectSetString(0, noteName, OBJPROP_TEXT, NoteText[row]);
   ObjectSetInteger(0, noteName, OBJPROP_ALIGN, ALIGN_LEFT);
   ObjectSetInteger(0, noteName, OBJPROP_READONLY, false);
   ObjectSetInteger(0, noteName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, noteName, OBJPROP_ZORDER, 1);
}

//+------------------------------------------------------------------+
//| Get button color based on state                                   |
//+------------------------------------------------------------------+
color GetButtonColor(int row, int col)
{
   switch(ButtonState[row][col])
   {
      case 0: return InpColorGray;
      case 1: return InpColorGreen;
      case 2: return InpColorRed;
      default: return InpColorGray;
   }
}

//+------------------------------------------------------------------+
//| Update button color after state change                            |
//+------------------------------------------------------------------+
void UpdateButtonColor(int row, int col)
{
   string btnName = PREFIX + "Btn_" + IntegerToString(row) + "_" + IntegerToString(col);
   ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, GetButtonColor(row, col));
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
