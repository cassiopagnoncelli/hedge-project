//+------------------------------------------------------------------+
//|                                                  MM3_Trender.mq4 |
//|                                 André Novais, Cássio Pagnoncelli |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "André Novais, Cássio Pagnoncelli"
#property link      ""

/*
   Este é um SHORTER.
*/

extern int Lenta = 200;
extern int Rapida = 35;
extern int Sinal = 3;
extern int StopLoss = 80;
extern int TakeProfit = 600;

#include <ManejoDeOrdens.mqh>

//---- globais
int sinal_venda = 0;

int init() {
   return(0);
}

int deinit() {
   return(0);
}

int start() {
   EncerraTudo();
   //ContaEmTela();
   Comment(sinal_venda);

   AtualizaSinalVenda();
   if ( sinal_venda == 3 && !PosicaoAberta(OP_SELL) )
      OrderSend(Symbol(), OP_SELL, Lote(), Bid, 1, SL_TP(OP_SELL, Bid, -StopLoss), SL_TP(OP_SELL, Bid, TakeProfit));

   return(0);
}

void AtualizaSinalVenda() {
   double   MM_l = iMA(Symbol(), 0, Lenta, 0, MODE_SMA, PRICE_CLOSE, 0);
   double   MM_r = iMA(Symbol(), 0, Rapida, 0, MODE_SMA, PRICE_CLOSE, 0);
   double   MM_s = iMA(Symbol(), 0, Sinal, 0, MODE_SMA, PRICE_CLOSE, 0);
   double   MM_r_ant = iMA(Symbol(), 0, Rapida, 1, MODE_SMA, PRICE_CLOSE, 0);
   double   MM_s_ant = iMA(Symbol(), 0, Sinal, 1, MODE_SMA, PRICE_CLOSE, 0);
   
   switch ( sinal_venda ) {
      case 0:
         if ( MM_l <= MM_r )
            sinal_venda = 0;
         else if ( MM_l > MM_r )
            sinal_venda = 1;
      break;
      case 1:
         if ( MM_s > MM_r && MM_s_ant < MM_r_ant )
            sinal_venda = 2;
         else if ( MM_l <= MM_r ) 
            sinal_venda = 0;
      break;
      case 2:
         if ( MM_s < MM_r && MM_s_ant > MM_r_ant )
            sinal_venda = 3;
         else if ( MM_l <= MM_r ) 
            sinal_venda = 0;
      break;
      case 3:
         if ( MM_l <= MM_r ) {
            sinal_venda = 0;
         } else {
            sinal_venda = 1;
         }
      break;
   }
   
}
