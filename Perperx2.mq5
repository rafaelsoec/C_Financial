//+------------------------------------------------------------------+
//|                   DualCCI_Candle_M15_ATR_Martingale.mq5          |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

// ========================= INPUTS =================================
input ENUM_TIMEFRAMES TimeFrame          = PERIOD_M15;
input double          Lote               = 0.10;
input double          LotMultiplier      = 1.5;      // 1.0 = sem martingale
input int             MaxMartingaleSteps = 5;        // segurança máximo

input int             FastCCIPeriod      = 14;
input int             SlowCCIPeriod      = 50;
input int             EMAPeriod          = 34;
input int             ATRPeriod          = 14;

input double          ATRStopMultiplier  = 1.0;
input double          ATRTakeMultiplier  = 2.0;

input bool            UseBreakEven       = true;
input double          BreakEvenATR       = 1.0;
input double          BreakEvenOffsetATR = 0.10;

input bool            UseTrailing        = true;
input double          TrailingStartATR   = 1.0;
input double          TrailingATR        = 0.8;

input long            MagicNumber        = 20260427;

// ========================= CONTROLE =================================
int fastCCIHandle = INVALID_HANDLE;
int slowCCIHandle = INVALID_HANDLE;
int emaHandle     = INVALID_HANDLE;
int atrHandle     = INVALID_HANDLE;

datetime lastBarTime = 0;

int       currentStepBuy   = 0;
int       currentStepSell  = 0;
datetime  lastCloseDateBuy  = 0;
datetime  lastCloseDateSell = 0;

// ========================= FUNCTIONS =================================
double GetDynamicLot(ENUM_POSITION_TYPE type)
{
   if(type == POSITION_TYPE_BUY)
   {
      if(LotMultiplier <= 0.99)
         return Lote;

      double lot = Lote * MathPow(LotMultiplier, currentStepBuy);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      lot = MathMax(minLot, MathMin(maxLot, lot));
      lot = MathFloor(lot / step) * step;
      return lot;
   }

   if(type == POSITION_TYPE_SELL)
   {
      if(LotMultiplier <= 0.99)
         return Lote;

      double lot = Lote * MathPow(LotMultiplier, currentStepSell);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      lot = MathMax(minLot, MathMin(maxLot, lot));
      lot = MathFloor(lot / step) * step;
      return lot;
   }

   return Lote;
}

//+------------------------------------------------------------------+
int OnInit()
{
   fastCCIHandle = iCCI(_Symbol, TimeFrame, FastCCIPeriod, PRICE_TYPICAL);
   slowCCIHandle = iCCI(_Symbol, TimeFrame, SlowCCIPeriod, PRICE_TYPICAL);
   emaHandle     = iMA(_Symbol, TimeFrame, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle     = iATR(_Symbol, TimeFrame, ATRPeriod);

   if(fastCCIHandle == INVALID_HANDLE ||
      slowCCIHandle == INVALID_HANDLE ||
      emaHandle     == INVALID_HANDLE ||
      atrHandle     == INVALID_HANDLE)
   {
      Print("Erro ao criar indicadores: ", GetLastError());
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastCCIHandle != INVALID_HANDLE) IndicatorRelease(fastCCIHandle);
   if(slowCCIHandle != INVALID_HANDLE) IndicatorRelease(slowCCIHandle);
   if(emaHandle     != INVALID_HANDLE) IndicatorRelease(emaHandle);
   if(atrHandle     != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   UpdateMartingaleFromHistory();
   ManagePosition();

   if(!IsNewBar())
      return;

   if(!PositionSelect(_Symbol))
      CheckEntry();
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, TimeFrame, 0);

   if(currentBarTime == 0)
      return false;

   if(lastBarTime == 0)
   {
      lastBarTime = currentBarTime;
      return false;
   }

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
bool IndicatorsReady()
{
   if(BarsCalculated(fastCCIHandle) < 20) return false;
   if(BarsCalculated(slowCCIHandle) < 20) return false;
   if(BarsCalculated(emaHandle)     < 20) return false;
   if(BarsCalculated(atrHandle)     < 20) return false;
   return true;
}

//+------------------------------------------------------------------+
bool GetRates(MqlRates &rates[])
{
   ArraySetAsSeries(rates, true);
   return CopyRates(_Symbol, TimeFrame, 0, 6, rates) >= 4;
}

//+------------------------------------------------------------------+
bool GetCCIValues(double &fast1, double &fast2, double &fast3,
                  double &slow1, double &slow2)
{
   if(!IndicatorsReady())
      return false;

   double fastBuf[], slowBuf[];
   ArraySetAsSeries(fastBuf, true);
   ArraySetAsSeries(slowBuf, true);

   if(CopyBuffer(fastCCIHandle, 0, 1, 3, fastBuf) < 3)
      return false;

   if(CopyBuffer(slowCCIHandle, 0, 1, 2, slowBuf) < 2)
      return false;

   fast1 = fastBuf[0];
   fast2 = fastBuf[1];
   fast3 = fastBuf[2];
   slow1 = slowBuf[0];
   slow2 = slowBuf[1];

   return true;
}

//+------------------------------------------------------------------+
bool GetEMA(double &ema1)
{
   if(!IndicatorsReady())
      return false;

   double emaBuf[];
   ArraySetAsSeries(emaBuf, true);

   if(CopyBuffer(emaHandle, 0, 1, 1, emaBuf) < 1)
      return false;

   ema1 = emaBuf[0];
   return true;
}

//+------------------------------------------------------------------+
double GetATR()
{
   if(!IndicatorsReady())
      return 0.0;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(atrHandle, 0, 1, 1, atrBuf) < 1)
      return 0.0;

   return atrBuf[0];
}

//+------------------------------------------------------------------+
bool BullishCandleConfirm(const MqlRates &rates[])
{
   return (rates[1].close > rates[1].open &&
           rates[1].close > rates[2].high);
}

//+------------------------------------------------------------------+
bool BearishCandleConfirm(const MqlRates &rates[])
{
   return (rates[1].close < rates[1].open &&
           rates[1].close < rates[2].low);
}

//+------------------------------------------------------------------+
bool FastCCIRecoveredFromOversold(double fast1, double fast2, double fast3)
{
   return (fast3 < -100 && fast2 < 0 && fast1 > 0);
}

//+------------------------------------------------------------------+
bool FastCCIFellFromOverbought(double fast1, double fast2, double fast3)
{
   return (fast3 > 100 && fast2 > 0 && fast1 < 0);
}

//+------------------------------------------------------------------+
void CheckEntry()
{
   MqlRates rates[];
   double fast1, fast2, fast3, slow1, slow2, ema1;
   double atr = GetATR();

   if(!GetRates(rates)) return;
   if(!GetCCIValues(fast1, fast2, fast3, slow1, slow2)) return;
   if(!GetEMA(ema1)) return;
   if(atr <= 0.0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool slowBullCross = (slow2 <= 0 && slow1 > 0);
   bool slowBearCross = (slow2 >= 0 && slow1 < 0);

   bool fastBullAgree = (fast1 > 0 && FastCCIRecoveredFromOversold(fast1, fast2, fast3));
   bool fastBearAgree = (fast1 < 0 && FastCCIFellFromOverbought(fast1, fast2, fast3));

   bool priceBull = rates[1].close > ema1;
   bool priceBear = rates[1].close < ema1;

   bool candleBull = BullishCandleConfirm(rates);
   bool candleBear = BearishCandleConfirm(rates);

   if(slowBullCross && fastBullAgree && priceBull && candleBull)
   {
      double sl = ask - (atr * ATRStopMultiplier);
      double tp = ask + (atr * ATRTakeMultiplier);
      double lot = GetDynamicLot(POSITION_TYPE_BUY);

      if(trade.Buy(lot, _Symbol, ask, sl, tp, "BUY DualCCI ATR Martingale"))
         Print("Compra aberta | Lote=", DoubleToString(lot, 2), " Etapa=", currentStepBuy);
      else
         Print("Erro compra: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }

   if(slowBearCross && fastBearAgree && priceBear && candleBear)
   {
      double sl = bid + (atr * ATRStopMultiplier);
      double tp = bid - (atr * ATRTakeMultiplier);
      double lot = GetDynamicLot(POSITION_TYPE_SELL);

      if(trade.Sell(lot, _Symbol, bid, sl, tp, "SELL DualCCI ATR Martingale"))
         Print("Venda aberta | Lote=", DoubleToString(lot, 2), " Etapa=", currentStepSell);
      else
         Print("Erro venda: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void UpdateMartingaleFromHistory()
{
   datetime start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime end   = TimeCurrent();

   if(!HistorySelect(start, end))
      return;

   int lastDeal = HistoryDealsTotal() - 1;

   for(int i = lastDeal; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long magic    = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      long entry    = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      long direction= HistoryDealGetInteger(ticket, DEAL_TYPE);

      if(symbol != _Symbol) continue;
      if(magic  != MagicNumber) continue;
      if(entry  != DEAL_ENTRY_OUT) continue;

      datetime closeTime = HistoryDealGetInteger(ticket, DEAL_TIME);

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                    + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                    + HistoryDealGetDouble(ticket, DEAL_SWAP);

      ENUM_POSITION_TYPE type = (direction == DEAL_TYPE_SELL) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

      if(profit > 0)
      {
         if(type == POSITION_TYPE_BUY && closeTime != lastCloseDateBuy)
         {
            lastCloseDateBuy = closeTime;
            currentStepBuy   = 0;
         }

         if(type == POSITION_TYPE_SELL && closeTime != lastCloseDateSell)
         {
            lastCloseDateSell = closeTime;
            currentStepSell   = 0;
         }
      }
      else
      {
         if(type == POSITION_TYPE_BUY && closeTime != lastCloseDateBuy)
         {
            lastCloseDateBuy = closeTime;
            currentStepBuy   = MathMin(currentStepBuy + 1, MaxMartingaleSteps);
         }

         if(type == POSITION_TYPE_SELL && closeTime != lastCloseDateSell)
         {
            lastCloseDateSell = closeTime;
            currentStepSell   = MathMin(currentStepSell + 1, MaxMartingaleSteps);
         }
      }

      break; // só o último trade
   }
}

//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!PositionSelect(_Symbol))
      return;

   double fast1, fast2, fast3, slow1, slow2;
   MqlRates rates[];

   if(!GetRates(rates)) return;
   if(!GetCCIValues(fast1, fast2, fast3, slow1, slow2)) return;

   double atr = GetATR();
   if(atr <= 0.0) return;

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl        = PositionGetDouble(POSITION_SL);
   double tp        = PositionGetDouble(POSITION_TP);

   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool exitBuy  = (slow2 >= 0 && slow1 < 0) || (fast2 >= 100 && fast1 < 100);
   bool exitSell = (slow2 <= 0 && slow1 > 0) || (fast2 <= -100 && fast1 > -100);

   if(type == POSITION_TYPE_BUY && exitBuy)
   {
      if(trade.PositionClose(_Symbol))
         Print("Compra fechada");
      return;
   }

   if(type == POSITION_TYPE_SELL && exitSell)
   {
      if(trade.PositionClose(_Symbol))
         Print("Venda fechada");
      return;
   }

   if(UseBreakEven)
   {
      double beTrigger = atr * BreakEvenATR;
      double beOffset  = atr * BreakEvenOffsetATR;

      if(type == POSITION_TYPE_BUY)
      {
         if((bid - openPrice) >= beTrigger)
         {
            double newSL = openPrice + beOffset;
            if(newSL > sl)
            {
               if(!trade.PositionModify(_Symbol, newSL, tp))
                  Print("Erro break-even BUY: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
            }
         }
      }

      if(type == POSITION_TYPE_SELL)
      {
         if((openPrice - ask) >= beTrigger)
         {
            double newSL = openPrice - beOffset;
            if(sl == 0.0 || newSL < sl)
            {
               if(!trade.PositionModify(_Symbol, newSL, tp))
                  Print("Erro break-even SELL: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
            }
         }
      }
   }

   if(UseTrailing)
   {
      double trailingStart = atr * TrailingStartATR;
      double trailingDist  = atr * TrailingATR;

      if(type == POSITION_TYPE_BUY)
      {
         if((bid - openPrice) >= trailingStart)
         {
            double newSL = bid - trailingDist;
            if(newSL > sl && newSL > openPrice)
            {
               if(!trade.PositionModify(_Symbol, newSL, tp))
                  Print("Erro trailing BUY: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
            }
         }
      }

      if(type == POSITION_TYPE_SELL)
      {
         if((openPrice - ask) >= trailingStart)
         {
            double newSL = ask + trailingDist;
            if((sl == 0.0 || newSL < sl) && newSL < openPrice)
            {
               if(!trade.PositionModify(_Symbol, newSL, tp))
                  Print("Erro trailing SELL: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
            }
         }
      }
   }
}
