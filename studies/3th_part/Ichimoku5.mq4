//+------------------------------------------------------------------+
//|                           Copyright 2005,  bobammax              |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Copyright 2005, bobammax aka foreverold"
#property link      ""




#define MAGIC 85718

extern double lStopLoss = 37;
extern double sStopLoss = 35;
extern double lTakeProfit = 80;
extern double sTakeProfit = 75;
extern double lTrailingStop = 20;
extern double sTrailingStop = 20;
extern color clOpenBuy = Blue;
extern color clCloseBuy = Aqua;
extern color clOpenSell = Red;
extern color clCloseSell = Violet;
extern color clModiBuy = Blue;
extern color clModiSell = Red;
extern string Name_Expert = "Ichimoku";
extern int Slippage = 4;
extern bool UseSound = True;
extern string NameFileSound = "alert.wav";
extern double Lots = 1.00;


void deinit() {
   Comment("");
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start(){
   if(Bars<100){
      Print("bars less than 100");
      return(0);
   }
   if(lStopLoss<10){
      Print("StopLoss less than 10");
      return(0);
   }
   if(lTakeProfit<10){
      Print("TakeProfit less than 10");
      return(0);
   }
   if(sStopLoss<10){
      Print("StopLoss less than 10");
      return(0);
   }
   if(sTakeProfit<10){
      Print("TakeProfit less than 10");
      return(0);
   }

   double diCustom0=iCustom(NULL, 240, "Ichimoku", 9, 26, 52, 0, 0);
   double diCustom1=iCustom(NULL, 240, "Ichimoku", 9, 26, 52, 1, 0);
   double diCustom2=iCustom(NULL, 240, "Ichimoku", 9, 26, 52, 1, 0);
   double diMA3=iMA(NULL,240,34,0,MODE_EMA,PRICE_CLOSE,0);
   double diCustom4=iCustom(NULL, 240, "Ichimoku", 9, 26, 52, 1, 0);
   double diCustom5=iCustom(NULL, 240, "Ichimoku", 9, 26, 52, 0, 0);

   if(AccountFreeMargin()<(1000*Lots)){
      Print("We have no money. Free Margin = ", AccountFreeMargin());
      return(0);
   }
   if (!ExistPositions()){

      if ((diCustom0>diCustom1 && diCustom2>diMA3)){
         OpenBuy();
         return(0);
      }

      if ((diCustom4>diCustom5)){
         OpenSell();
         return(0);
      }
   }
   TrailingPositionsBuy(lTrailingStop);
   TrailingPositionsSell(sTrailingStop);
   return (0);
}

bool ExistPositions() {
	for (int i=0; i<OrdersTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==MAGIC) {
				return(True);
			}
		} 
	} 
	return(false);
}
void TrailingPositionsBuy(int trailingStop) { 
   for (int i=0; i<OrdersTotal(); i++) { 
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { 
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==MAGIC) { 
            if (OrderType()==OP_BUY) { 
               if (Bid-OrderOpenPrice()>trailingStop*Point) { 
                  if (OrderStopLoss()<Bid-trailingStop*Point) 
                     ModifyStopLoss(Bid-trailingStop*Point); 
               } 
            } 
         } 
      } 
   } 
} 
void TrailingPositionsSell(int trailingStop) { 
   for (int i=0; i<OrdersTotal(); i++) { 
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { 
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==MAGIC) { 
            if (OrderType()==OP_SELL) { 
               if (OrderOpenPrice()-Ask>trailingStop*Point) { 
                  if (OrderStopLoss()>Ask+trailingStop*Point || OrderStopLoss()==0)  
                     ModifyStopLoss(Ask+trailingStop*Point); 
               } 
            } 
         } 
      } 
   } 
} 
void ModifyStopLoss(double ldStopLoss) { 
   bool fm;
   fm = OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE); 
   if (fm && UseSound) PlaySound(NameFileSound); 
} 

void OpenBuy() { 
   double ldLot, ldStop, ldTake; 
   string lsComm; 
   ldLot = GetSizeLot(); 
   ldStop = GetStopLossBuy(); 
   ldTake = GetTakeProfitBuy(); 
   lsComm = GetCommentForOrder(); 
   OrderSend(Symbol(),OP_BUY,ldLot,Ask,Slippage,ldStop,ldTake,lsComm,MAGIC,0,clOpenBuy); 
   if (UseSound) PlaySound(NameFileSound); 
} 
void OpenSell() { 
   double ldLot, ldStop, ldTake; 
   string lsComm; 

   ldLot = GetSizeLot(); 
   ldStop = GetStopLossSell(); 
   ldTake = GetTakeProfitSell(); 
   lsComm = GetCommentForOrder(); 
   OrderSend(Symbol(),OP_SELL,ldLot,Bid,Slippage,ldStop,ldTake,lsComm,MAGIC,0,clOpenSell); 
   if (UseSound) PlaySound(NameFileSound); 
} 
string GetCommentForOrder() { 	return(Name_Expert); } 
double GetSizeLot() { 	return(Lots); } 
double GetStopLossBuy() { 	return (Bid-lStopLoss*Point);} 
double GetStopLossSell() { 	return(Ask+sStopLoss*Point); } 
double GetTakeProfitBuy() { 	return(Ask+lTakeProfit*Point); } 
double GetTakeProfitSell() { 	return(Bid-sTakeProfit*Point); } 

