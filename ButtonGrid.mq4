//+------------------------------------------------------------------+
//|                                                   ButtonGrid.mq4 |
//|                              Custom Button Grid Indicator        |
//|                         28 rows x 3 columns (H1, H4, D1)         |
//+------------------------------------------------------------------+
#property copyright "Custom Indicator"
#property link      ""
#property version   "1.02"
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
//| COLOR PARAMETERS - Customize all colors from Inputs tab          |
//+------------------------------------------------------------------+
input color  InpColorGray      = clrDimGray;     // Button Color: Gray (default)
input color  InpColorGreen     = clrLime;        // Button Color: Green (1st click)
input color  InpColorRed       = clrRed;         // Button Color: Red (2nd click)
input color  InpColorBorder    = clrGray;        // Button Border Color
input color  InpHeaderTextColor= clrYellow;      // Header Text Color (H1/H4/D1)
input int    InpHeaderFontSize = 8;              // Header Font Size

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

// Object name prefix
string PREFIX = "BtnGrid_";

// Column headers
string ColHeaders[COLS] = {"H1", "H4", "D1"};

// State file path
string StateFilePath;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Build state file path (saved in MQL4/Files folder)
   // Using single shared file for all charts/symbols
   StateFilePath = InpStateFileName + ".dat";

   // Initialize all buttons to gray state (0)
   for(int row = 0; row < ROWS; row++)
   {
      for(int col = 0; col < COLS; col++)
      {
         ButtonState[row][col] = 0;
      }
   }

   // Load saved states from file (if exists)
   LoadButtonStates();

   // Enable chart events for click detection
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   // Create the button grid
   CreateButtonGrid();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save button states before removing indicator
   SaveButtonStates();

   // Remove all objects created by this indicator
   ObjectsDeleteAll(0, PREFIX);
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
//| ChartEvent function - handles mouse clicks                        |
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
//| Create the entire button grid                                     |
//+------------------------------------------------------------------+
void CreateButtonGrid()
{
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

   // Create button grid
   for(int row = 0; row < ROWS; row++)
   {
      for(int col = 0; col < COLS; col++)
      {
         CreateButton(row, col);
      }
   }
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
