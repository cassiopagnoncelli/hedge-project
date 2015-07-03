//+------------------------------------------------------------------+
//|                                                Cruzamento_MM.mq4 |
//|                André Duarte de Novais, Cássio Jandir Pagnoncelli |
//|                                          www.inf.ufpr.br/~cjp07/ |
//+------------------------------------------------------------------+
#property copyright "André Duarte de Novais, Cássio Jandir Pagnoncelli"

// Parâmetros
extern int       Periodicidade_MME_Lenta = 140;
extern int       Periodicidade_MME_Rapida = 21;
extern double    Tamanho_do_lote = 0.03;
extern double    TAKE_PROFIT, STOP_LOSS;

double MA_rapida, MA_lenta, pip;
bool rapida_acima_da_lenta_ANTERIOR, rapida_acima_da_lenta;
int ultimo_ticket;

int init() {
     ultimo_ticket = 0;
     pip = 0.0001;

     // Guarda o estado das MME (qual esta por cima)
     MA_rapida = iMA(Symbol(), 0, Periodicidade_MME_Rapida, 0, MODE_EMA, PRICE_TYPICAL, 0);
     MA_lenta  = iMA(Symbol(), 0, Periodicidade_MME_Lenta, 0, MODE_EMA, PRICE_TYPICAL, 0);  
     if ( MA_rapida > MA_lenta ) 
          rapida_acima_da_lenta_ANTERIOR = true;
     else 
          rapida_acima_da_lenta_ANTERIOR = false;
     
     return (0);
}

int deinit(){ 
     return (0);
}

int start() {
     // Valor das MME no tick atual
     MA_rapida = iMA(Symbol(), 0, Periodicidade_MME_Rapida, 0, MODE_EMA, PRICE_TYPICAL, 0);
     MA_lenta  = iMA(Symbol(), 0, Periodicidade_MME_Lenta, 0, MODE_EMA, PRICE_TYPICAL, 0);
     
     // Verifica qual MME está por cima
     if ( MA_rapida > MA_lenta ) 
          rapida_acima_da_lenta = true;
     else 
          rapida_acima_da_lenta = false;

     // Realiza operacoes nos cruzamentos das MME
     if ( rapida_acima_da_lenta_ANTERIOR && !rapida_acima_da_lenta ) // MMs se cruzaram
          ultimo_ticket = encerra_e_vende(Tamanho_do_lote);
     else if ( !rapida_acima_da_lenta_ANTERIOR && rapida_acima_da_lenta ) // MMs se cruzaram no sentido oposto
          ultimo_ticket = encerra_e_compra(Tamanho_do_lote);

     // Guarda o estado de alinhamento das MME pra ser usado no ticket seguinte
     rapida_acima_da_lenta_ANTERIOR = rapida_acima_da_lenta;
     
     return (0);
}

// Encerra a posicao de venda e realiza uma compra
int encerra_e_compra(double lote) {
     if ( ultimo_ticket != 0 ) 
          OrderClose(ultimo_ticket, lote, Ask, 0); 
          
     if ( STOP_LOSS == 0 && TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, 0, 0)); 
     else if ( STOP_LOSS == 0 ) 
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, 0, Ask + TAKE_PROFIT * pip)); 
     else if ( TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, Ask - STOP_LOSS * pip, 0)); 
     else
          return (OrderSend(Symbol(), OP_BUY, lote, Ask, 0, Ask - STOP_LOSS * pip, Ask + TAKE_PROFIT * pip)); 
}

// Encerra a posicao de compra e realiza uma venda a descoberto
int encerra_e_vende(double lote) {
     if ( ultimo_ticket != 0 )
          OrderClose(ultimo_ticket, lote, Bid, 0);
     
     if ( STOP_LOSS == 0 && TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, 0, Bid - TAKE_PROFIT * pip));
     else if ( STOP_LOSS == 0 )
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, 0, Bid - TAKE_PROFIT * pip));
     else if ( TAKE_PROFIT == 0 )
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, Bid + STOP_LOSS * pip, 0));
     else
          return (OrderSend(Symbol(), OP_SELL, lote, Bid, 0, Bid + STOP_LOSS * pip, Bid - TAKE_PROFIT * pip));
}
