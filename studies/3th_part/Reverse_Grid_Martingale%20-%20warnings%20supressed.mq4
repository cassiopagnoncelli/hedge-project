//+------------------------------------------------------------------+
//|                                     Reverse_Grid_Martingale .mq4 |
//|                              Copyright © 2008, Constin           |
//|                                             Constin@ForexFactory |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2008, Constin"
#property link      "Constin@ForexFactory"

extern int MaximumNumberOfOrdersToSend=12;
extern bool LongOnly=false;
extern bool Reverse=true;
extern double StepSizeInPips=50;
extern double ReversalStepSizeInPips=20;
extern int MagicNumber=10126;
extern int MaxSlippage=2;
int spread=0;

extern double LotSize1=4;
extern double LotSize2=4;
extern double LotSize3=3;
extern double LotSize4=2;
extern double LotSize5=1;
extern double LotSize6=1;
extern double LotSize7=1;
extern double LotSize8=1;
extern double LotSize9=1;
extern double LotSize10=1;
extern double LotSize11=1;
extern double LotSize12=1;
extern double LotSize13=1;
extern double LotSize14=1;
extern double LotSize15=1;
extern double LotSize16=1;
extern double LotSize17=1;
extern double LotSize18=1;
extern double LotSize19=1;
extern double LotSize20=1;
extern double LotSize21=1;
extern double LotSize22=1;
extern double LotSize23=1;
extern double LotSize24=1;
extern double LotSize25=1;
extern double LotSize26=1;
extern double LotSize27=1;
extern double LotSize28=1;
extern double LotSize29=1;
extern double LotSize30=0.5;

double LotSizes[31];
int openLongs,openShorts;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
LotSizes[1]=LotSize1;
LotSizes[2]=LotSize2;
LotSizes[3]=LotSize3;
LotSizes[4]=LotSize4;
LotSizes[5]=LotSize5;
LotSizes[6]=LotSize6;
LotSizes[7]=LotSize7;
LotSizes[8]=LotSize8;
LotSizes[9]=LotSize9;
LotSizes[10]=LotSize10;
LotSizes[11]=LotSize11;
LotSizes[12]=LotSize12;
LotSizes[13]=LotSize13;
LotSizes[14]=LotSize14;
LotSizes[15]=LotSize15;
LotSizes[16]=LotSize16;
LotSizes[17]=LotSize17;
LotSizes[18]=LotSize18;
LotSizes[19]=LotSize19;
LotSizes[20]=LotSize20;
LotSizes[21]=LotSize21;
LotSizes[22]=LotSize22;
LotSizes[23]=LotSize23;
LotSizes[24]=LotSize24;
LotSizes[25]=LotSize25;
LotSizes[26]=LotSize26;
LotSizes[27]=LotSize27;
LotSizes[28]=LotSize28;
LotSizes[29]=LotSize29;
LotSizes[30]=LotSize30;
Print("**** starting up");
if(Reverse)
{
if(LongOnly) PlaceLongOrders(); else PlaceShortOrders();
}
else
{
if(LongOnly) PlaceLongOrders(); else PlaceShortOrders();
}
//updatePositionCounts();
return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
Comment("Longs: "+openLongs+" shorts: "+openShorts+" reported longs:"+openPositions(OP_BUY)+" reported shorts:"+openPositions(OP_SELL));
check();
   return(0);
  }
//+------------------------------------------------------------------+

void updatePositionCounts(){
openLongs=openPositions(OP_BUY);
openShorts=openPositions(OP_SELL);
}


/*void initialOrders(){
//OrderSend(Symbol(),OP_BUY,LotSizes[1],Ask,MaxSlippage,NormalizeDouble(Ask-StepSizeInPips*Point,Digits),0,"Long 1",MagicNumber,0);
//OrderSend(Symbol(),OP_SELL,LotSizes[1],Bid,MaxSlippage,NormalizeDouble(Bid+StepSizeInPips*Point,Digits),0,"Short 1",MagicNumber,0);

}
*/

void PlaceLongOrders()
{
OrderSend(Symbol(),OP_BUY,LotSizes[1],Ask,MaxSlippage,NormalizeDouble(Ask-ReversalStepSizeInPips*Point,Digits),0,"Long 1",MagicNumber,0);
for(int c=1;c<=(MaximumNumberOfOrdersToSend-1);c++){
   OrderSend(Symbol(),OP_BUYSTOP,LotSizes[c+1],NormalizeDouble(Ask+(StepSizeInPips*c*Point),Digits),MaxSlippage,
   NormalizeDouble((Ask+(StepSizeInPips*c*Point))-(ReversalStepSizeInPips*Point),Digits),0,"Long "+DoubleToStr(c+1,0),MagicNumber,0);
   }
updatePositionCounts();   
}

void PlaceShortOrders()
{
OrderSend(Symbol(),OP_SELL,LotSizes[1],Bid,MaxSlippage,NormalizeDouble(Bid+ReversalStepSizeInPips*Point,Digits),0,"Short 1",MagicNumber,0);
for(int c=1;c<=(MaximumNumberOfOrdersToSend-1);c++){
   OrderSend(Symbol(),OP_SELLSTOP,LotSizes[c+1],NormalizeDouble(Bid-(StepSizeInPips*c*Point),Digits),MaxSlippage,
   NormalizeDouble((Bid-(StepSizeInPips*c*Point))+(ReversalStepSizeInPips*Point),Digits),0,"Short "+DoubleToStr(c+1,0),MagicNumber,0);
   }
updatePositionCounts();   
}


int openPositions(int type){
   int Total = OrdersTotal();
   int long=0;int short=0;
   int ret = -1;
   for (int i = 0; i < Total; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderMagicNumber()==MagicNumber && (OrderType()==OP_BUY || OrderType()==OP_SELL   )    ) {
        if (OrderType()==OP_BUY) long++;
        if (OrderType()==OP_SELL) short++;
      }
   }
if(type==OP_SELL) ret=short;   
if(type==OP_BUY) ret=long;
return(ret);
}

int outstandingOrders(int type){
   int Total = OrdersTotal();
   int long=0;int short=0;
   int ret = -1;
   for (int i = 0; i < Total; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderMagicNumber()==MagicNumber && (OrderType()==OP_BUYSTOP || OrderType()==OP_SELLSTOP   )    ) {
        if (OrderType()==OP_BUYSTOP) long++;
        if (OrderType()==OP_SELLSTOP) short++;
      }
   }
if(type==OP_SELLSTOP) ret=short;   
if(type==OP_BUYSTOP) ret=long;
return(ret);
}


/*void deletePending()
  {
   bool flag;
   for(int cnt=OrdersTotal()-1; cnt>=0; cnt--)
     {
      flag=false;
      if(OrderSelect(cnt,SELECT_BY_POS) && OrderSymbol()==Symbol())
        {
         if(OrderType()!=OP_SELL && OrderType()!=OP_BUY && OrderMagicNumber()==MagicNumber) { flag=true; OrderDelete(OrderTicket()); }
         if(flag)
           {
            Sleep(500);
            RefreshRates();
           }
        }
     }
   return(0);
  }

void deletePendingOrdersOfType(int type)
  {
   bool flag;
   for(int cnt=OrdersTotal()-1; cnt>=0; cnt--)
     {
      flag=false;
      if(OrderSelect(cnt,SELECT_BY_POS) && OrderSymbol()==Symbol())
        {
         if(OrderType()==type && OrderMagicNumber()==MagicNumber) { flag=true;Print("Deleting:"+OrderTicket()); OrderDelete(OrderTicket()); }
         /*if(flag)
           {
            Sleep(500);
            RefreshRates();
           }
        }
     }
   return(0);
  }
*/
void deleteFirstPendingOrdersOfType(int type)
  {
   bool flag;
   bool done=false;
   int tot=OrdersTotal();
   int i=0;
   while(!done)
     {
      flag=false;
      if(OrderSelect(i,SELECT_BY_POS) && OrderSymbol()==Symbol())
        {
         if(OrderType()==type && OrderMagicNumber()==MagicNumber) { flag=true;Print("Deleting:"+OrderTicket()); OrderDelete(OrderTicket());done=true; }
         /*if(flag)
           {
            Sleep(500);
            RefreshRates();
           }*/
        }
     i++;
     if (i==tot) {done=true;}
     }
   return(0);
  }


void closeShorts()
{
    int Total = OrdersTotal();
    for (int i = 0; i < Total; i ++) {
        OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber()==MagicNumber && (OrderType()==OP_SELL   )    ) {
            OrderClose(OrderTicket(),OrderLots(),Ask,MaxSlippage);
        }
    }
}

void closeLongs()
{
    int Total = OrdersTotal();
    for (int i = 0; i < Total; i ++) {
        OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber()==MagicNumber && (OrderType()==OP_BUY   )    ) {
            OrderClose(OrderTicket(),OrderLots(),Bid,MaxSlippage);
        }
    }
}
  
void check()
{
if((openPositions(OP_BUY)<openLongs)) 
   {
   //Print("*** e' stato chiuso un long");
   while ( outstandingOrders(OP_BUYSTOP)>0 ) { deleteFirstPendingOrdersOfType(OP_BUYSTOP);}
   //Print("*** Longs: "+openLongs+" shorts: "+openShorts+" reported longs:"+openPositions(OP_BUY)+" reported shorts:"+openPositions(OP_SELL));
   closeLongs();
   //Print("pare ci siano questo numero di sellstop:"+outstandingOrders(OP_SELLSTOP));
   if((Reverse) && (outstandingOrders(OP_SELLSTOP)==0)) {Print("*** reversing");PlaceShortOrders(); }
   if (!Reverse)  {Print("*** restarting");PlaceLongOrders();}
   
   }
if((openPositions(OP_SELL)<openShorts)) 
   {
   //Print("*** e' stato chiuso uno short");
   while ( outstandingOrders(OP_SELLSTOP)>0 ) {deleteFirstPendingOrdersOfType(OP_SELLSTOP);}
   //Print("*** Longs: "+openLongs+" shorts: "+openShorts+" reported longs:"+openPositions(OP_BUY)+" reported shorts:"+openPositions(OP_SELL));
   closeShorts();
   //Print("pare ci siano questo numero di buystop:"+outstandingOrders(OP_BUYSTOP));
   if((Reverse)  && (outstandingOrders(OP_BUYSTOP)==0)) {Print("*** reversing");PlaceLongOrders();}
   if (!Reverse) {Print("*** restarting");PlaceShortOrders();}
   
   }
updatePositionCounts();   
} 




