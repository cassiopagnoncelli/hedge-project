//+------------------------------------------------------------------+
//|                                                          DSR.mq4 |
//|                                                           doshur |
//|                 Donate via PayPal if you find this script useful |
//|                                                  dyrws@yahoo.com |
//|                                             www.doshur.com/forex |
//+------------------------------------------------------------------+
#property copyright "doshur"
#property link      "www.doshur.com"

extern int TF = 0;
extern color Clr = MediumOrchid;
extern int Style = 4;
extern int Lines = 5;
extern int Count = 100;
extern int Sensitivity = 15;

double PTs[1, 2];

#property indicator_chart_window
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//----

   ArrayResize(PTs, Count);

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
//----

   string Name;

   for(int i = 1; i <= Lines; i++)
   {
      Name = "Line_" + DoubleToStr(i, 0);

      if(ObjectFind(Name) == 0)
      {
         ObjectDelete(Name);
      }
   }

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
//---- VARIABLES

   int i, x, y, Pos, Cnt;
   double Curr_C, Prev_C, Past_C, tmpPrice;

//---- RESET

   ArrayInitialize(PTs, 0);

//---- SCAN CLOSE FRACTALS

   i = 1;
   x = 0;

   while(x < Count)
   {
      Cnt = 0;

      Curr_C = iClose(NULL, TF, i);
      Prev_C = iClose(NULL, TF, i + 1);
      Past_C = iClose(NULL, TF, i + 2);

      if((Curr_C < Prev_C && Prev_C > Past_C) || (Curr_C > Prev_C && Prev_C < Past_C))
      {
         PTs[x, 1] = Prev_C;
         x++;
      }

      i++;
   }

//---- ADD SENSITIVITY COUNTER

   for(i = 0; i < Count; i++)
   {
      Cnt = 0;

      for(x = 0; x < Count; x++)
      {
         if(MathAbs(PTs[i, 1] - PTs[x, 1]) <= Sensitivity * Point * 10)
         {
            Cnt++;
         }
      }

      PTs[i, 0] = Cnt;
   }

//---- SORT ARRAY

   ArraySort(PTs, WHOLE_ARRAY, 0, MODE_DESCEND);

//---- MERGE NEIGHBOUR

   for(i = 0; i < Count; i++)
   {
      y = 0;
      Cnt = 0;
      tmpPrice = 0;

      for(x = 0; x < Count; x++)
      {
         if(i != x)
         {
            if(MathAbs(PTs[i, 1] - PTs[x, 1]) <= Sensitivity * Point * 10)
            {
               y++;
               Cnt += PTs[x, 0];
               tmpPrice += PTs[x, 1];

               PTs[x, 0] = 0;
               PTs[x, 1] = 0;
            }
         }
      }

      if(y > 0)
      {
         y++;
         Cnt += PTs[i, 0];
         tmpPrice += PTs[i, 1];

         PTs[i, 0] = Cnt;
         PTs[i, 1] = tmpPrice / y;
      }
   }

//---- SORT ARRAY

   ArraySort(PTs, WHOLE_ARRAY, 0, MODE_DESCEND);

//---- DRAW LINES

   string Name;

   for(i = 1; i <= Lines; i++)
   {
      Name = "Line_" + DoubleToStr(i, 0);

      if(ObjectFind(Name) < 0)
      {
         if(PTs[i, 1] != 0)
         {
            ObjectCreate(Name, OBJ_HLINE, 0, 0, PTs[i, 1]);
            ObjectSet(Name, OBJPROP_COLOR, Clr);
            ObjectSet(Name, OBJPROP_STYLE, Style);
            ObjectSet(Name, OBJPROP_BACK, true);
         }
      }
      else
      {
         ObjectMove(Name, 0, Time[0], PTs[i, 1]);
      }
   }

//---- DEBUG

   //for(i = 0; i < Count; i++)
   //{
   //   Print(i, " - ", PTs[i, 0], " : ", PTs[i, 1]);
   //}

//----
   return(0);
  }