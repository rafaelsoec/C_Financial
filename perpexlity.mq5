//+------------------------------------------------------------------+
//|                 DualCCI_Candle_M15_ATR_Manage_Fixed.mq5          |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

 ENUM_TIMEFRAMES TimeFrame          = PERIOD_M15;
input double PERCENT_LOSS_PER_DAY = 2;
input double          Lote               = 0.10;
 int             FastCCIPeriod      = 14;
 int             SlowCCIPeriod      = 50;
 int             EMAPeriod          = 34;
 int             ATRPeriod          = 14;

 double          ATRStopMultiplier  = 1.0;
 double          ATRTakeMultiplier  = 2.0;

 bool            UseBreakEven       = true;
 double          BreakEvenATR       = 1.0;
 double          BreakEvenOffsetATR = 0.10;

 bool            UseTrailing        = true;
 double          TrailingStartATR   = 1.0;
 double          TrailingATR        = 0.8;

 long            MagicNumber        = 202604275525;

int fastCCIHandle = INVALID_HANDLE;
int slowCCIHandle = INVALID_HANDLE;
int emaHandle     = INVALID_HANDLE;
int atrHandle     = INVALID_HANDLE;
double BALANCE     = 0;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   fastCCIHandle = iCCI(_Symbol, TimeFrame, FastCCIPeriod, PRICE_TYPICAL);
   slowCCIHandle = iCCI(_Symbol, TimeFrame, SlowCCIPeriod, PRICE_TYPICAL);
   emaHandle     = iMA(_Symbol, TimeFrame, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle     = iATR(_Symbol, TimeFrame, ATRPeriod);
   BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);

   if(fastCCIHandle == INVALID_HANDLE ||
      slowCCIHandle == INVALID_HANDLE ||
      emaHandle     == INVALID_HANDLE ||
      atrHandle     == INVALID_HANDLE)
   {
      Print("Erro ao criar indicadores: ", GetLastError());
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(MagicNumber);
   Print("EA iniciado com sucesso.");
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
   if(!CheckDailyMaxLoss(PERCENT_LOSS_PER_DAY, "USD ")) {
        printf("Perda maxima atingida.");
        return;  // Não opera mais hoje
   }
   
   ManagePosition();

   if(!IsNewBar())
      return;

   if(!PositionSelect(_Symbol))
      CheckEntry();
      
   if(IsNewDay()){
      BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
   }   
}

bool IsNewDay() {
    static datetime last_day = 0;
    datetime current_day = iTime(_Symbol, PERIOD_D1, 0);  // Início do dia atual
    
    if(last_day != current_day) {
        last_day = current_day;
        return true;  // É novo dia!
    }
    return false;
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
double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}
//+------------------------------------------------------------------+
double GetMinStopDistancePrice()
{
   int stopsLevel  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

   int minLevel = MathMax(stopsLevel, freezeLevel);

   if(minLevel < 1)
      minLevel = 1;

   return minLevel * _Point;
}
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double vMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(vStep <= 0.0)
      return volume;

   volume = MathMax(vMin, MathMin(vMax, volume));
   volume = MathFloor(volume / vStep) * vStep;

   int volDigits = 2;
   return NormalizeDouble(volume, volDigits);
}
//+------------------------------------------------------------------+
bool OpenBuyATR(double lot, double atr, string comment)
{
   double ask     = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double minDist = GetMinStopDistancePrice();
   double volume  = NormalizeVolume(lot);

   double sl = NormalizePrice(ask - (atr * ATRStopMultiplier));
   double tp = NormalizePrice(ask + (atr * ATRTakeMultiplier));

   double maxAllowedSL = NormalizePrice(ask - minDist);
   double minAllowedTP = NormalizePrice(ask + minDist);

   if(sl >= maxAllowedSL)
      sl = NormalizePrice(maxAllowedSL - _Point);

   if(tp <= minAllowedTP)
      tp = NormalizePrice(minAllowedTP + _Point);

   Print("BUY DEBUG | ask=", ask,
         " | atr=", atr,
         " | lot=", volume,
         " | minDist=", minDist,
         " | sl=", sl,
         " | tp=", tp,
         " | stopsLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
         " | freezeLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));

   bool ok = trade.Buy(volume, _Symbol, ask, sl, tp, comment);

   if(ok)
      Print("Compra aberta com sucesso.");
   else
      Print("Erro compra: retcode=", trade.ResultRetcode(),
            " | desc=", trade.ResultRetcodeDescription());

   return ok;
}
//+------------------------------------------------------------------+
bool OpenSellATR(double lot, double atr, string comment)
{
   double bid     = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double ask     = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double minDist = GetMinStopDistancePrice();
   double volume  = NormalizeVolume(lot);

   double sl = NormalizePrice(bid + (atr * ATRStopMultiplier));
   double tp = NormalizePrice(bid - (atr * ATRTakeMultiplier));

   double minAllowedSL = NormalizePrice(ask + minDist);
   double maxAllowedTP = NormalizePrice(bid - minDist);

   if(sl <= minAllowedSL)
      sl = NormalizePrice(minAllowedSL + _Point);

   if(tp >= maxAllowedTP)
      tp = NormalizePrice(maxAllowedTP - _Point);

   Print("SELL DEBUG | bid=", bid,
         " | ask=", ask,
         " | atr=", atr,
         " | lot=", volume,
         " | minDist=", minDist,
         " | sl=", sl,
         " | tp=", tp,
         " | stopsLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
         " | freezeLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));

   bool ok = trade.Sell(volume, _Symbol, bid, sl, tp, comment);

   if(ok)
      Print("Venda aberta com sucesso.");
   else
      Print("Erro venda: retcode=", trade.ResultRetcode(),
            " | desc=", trade.ResultRetcodeDescription());

   return ok;
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

   bool slowBullCross = (slow2 <= 0 && slow1 > 0);
   bool slowBearCross = (slow2 >= 0 && slow1 < 0);

   bool fastBullAgree = (fast1 > 0 && FastCCIRecoveredFromOversold(fast1, fast2, fast3));
   bool fastBearAgree = (fast1 < 0 && FastCCIFellFromOverbought(fast1, fast2, fast3));

   bool priceBull = rates[1].close > ema1;
   bool priceBear = rates[1].close < ema1;

   bool candleBull = BullishCandleConfirm(rates);
   bool candleBear = BearishCandleConfirm(rates);

   Print("CHECK ENTRY | slowBullCross=", slowBullCross,
         " | slowBearCross=", slowBearCross,
         " | fastBullAgree=", fastBullAgree,
         " | fastBearAgree=", fastBearAgree,
         " | priceBull=", priceBull,
         " | priceBear=", priceBear,
         " | candleBull=", candleBull,
         " | candleBear=", candleBear,
         " | atr=", atr);

   if(slowBullCross && fastBullAgree && priceBull && candleBull)
   {
      Print("Sinal BUY encontrado.");
      OpenBuyATR(Lote, atr, "BUY DualCCI ATR");
   }

   if(slowBearCross && fastBearAgree && priceBear && candleBear)
   {
      Print("Sinal SELL encontrado.");
      OpenSellATR(Lote, atr, "SELL DualCCI ATR");
   }
}

bool CheckDailyMaxLoss(double percentLossPerDay, string log_prefix = "") {
    if(PERCENT_LOSS_PER_DAY <= 0) {
       return true;
    }
    static double daily_loss = 0.0;
    static datetime current_day = 0;
    double max_loss_dollars = BALANCE * (PERCENT_LOSS_PER_DAY / 100);
    
    datetime today = iTime(_Symbol, PERIOD_D1, 0);
    
    // Novo dia = reset perda
    if(current_day != today) {
        current_day = today;
        daily_loss = 0.0;
        if(log_prefix != "") Print(log_prefix, "🟢 NOVO DIA - Perda resetada");
        return true;
    }
    
    // Calcula perda do dia (todas posições)
    double today_loss = 0.0;
    HistorySelect(today, TimeCurrent());
    
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            today_loss += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            today_loss += HistoryDealGetDouble(ticket, DEAL_SWAP);
            today_loss += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
    }
    
    daily_loss = today_loss;
    
    if(daily_loss <= -max_loss_dollars) {
        if(log_prefix != "") {
            Print(log_prefix, "❌ MAX LOSS DIÁRIO ATINGIDO! $", 
                  DoubleToString(MathAbs(daily_loss), 2), "/", max_loss_dollars);
        }
        return false;  // Pare de operar
    }
    
    return true;  // Pode operar
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
   ulong magicNumberPos = PositionGetInteger(POSITION_MAGIC);

   double bid       = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double ask       = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   
   if (magicNumberPos != MagicNumber){
      return;
   }

   bool exitBuy  = (slow2 >= 0 && slow1 < 0) || (fast2 >= 100 && fast1 < 100);
   bool exitSell = (slow2 <= 0 && slow1 > 0) || (fast2 <= -100 && fast1 > -100);

   if(type == POSITION_TYPE_BUY && exitBuy)
   {
      if(trade.PositionClose(_Symbol))
         Print("Compra fechada.");
      else
         Print("Erro ao fechar compra: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      return;
   }

   if(type == POSITION_TYPE_SELL && exitSell)
   {
      if(trade.PositionClose(_Symbol))
         Print("Venda fechada.");
      else
         Print("Erro ao fechar venda: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
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
            double candidateSL = openPrice + beOffset;
            double newSL = AdjustStopForBuy(candidateSL, bid);
   
            if((sl == 0.0 || newSL > sl) && newSL < bid && IsDifferentPrice(newSL, sl))
            {
               ModifyPositionSL(newSL, tp);
            }
         }
      }
   
      if(type == POSITION_TYPE_SELL)
      {
         if((openPrice - ask) >= beTrigger)
         {
            double candidateSL = openPrice - beOffset;
            double newSL = AdjustStopForSell(candidateSL, ask);
   
            if((sl == 0.0 || newSL < sl) && newSL > ask && IsDifferentPrice(newSL, sl))
            {
               ModifyPositionSL(newSL, tp);
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
            double candidateSL = bid - trailingDist;
            double newSL = AdjustStopForBuy(candidateSL, bid);
   
            if((sl == 0.0 || newSL > sl) && newSL > openPrice && newSL < bid && IsDifferentPrice(newSL, sl))
            {
               ModifyPositionSL(newSL, tp);
            }
         }
      }
   
      if(type == POSITION_TYPE_SELL)
      {
         if((openPrice - ask) >= trailingStart)
         {
            double candidateSL = ask + trailingDist;
            double newSL = AdjustStopForSell(candidateSL, ask);
   
            if((sl == 0.0 || newSL < sl) && newSL < openPrice && newSL > ask && IsDifferentPrice(newSL, sl))
            {
               ModifyPositionSL(newSL, tp);
            }
         }
      }
   }
}

double GetProtectionDistance()
{
   int stopsLevel  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

   int level = MathMax(stopsLevel, freezeLevel);
   if(level < 1)
      level = 1;

   return level * _Point;
}

bool IsDifferentPrice(double a, double b)
{
   return MathAbs(NormalizeDouble(a, _Digits) - NormalizeDouble(b, _Digits)) >= (_Point * 0.5);
}

double AdjustStopForBuy(double candidateSL, double bid)
{
   double protectDist = GetProtectionDistance();
   double maxAllowedSL = NormalizeDouble(bid - protectDist, _Digits);

   if(candidateSL > maxAllowedSL)
      candidateSL = maxAllowedSL;

   return NormalizeDouble(candidateSL, _Digits);
}

double AdjustStopForSell(double candidateSL, double ask)
{
   double protectDist = GetProtectionDistance();
   double minAllowedSL = NormalizeDouble(ask + protectDist, _Digits);

   if(candidateSL < minAllowedSL)
      candidateSL = minAllowedSL;

   return NormalizeDouble(candidateSL, _Digits);
}

bool ModifyPositionSL(double newSL, double currentTP)
{
   newSL = NormalizeDouble(newSL, _Digits);
   currentTP = NormalizeDouble(currentTP, _Digits);

   bool ok = trade.PositionModify(_Symbol, newSL, currentTP);

   if(!ok)
   {
      Print("Erro PositionModify | SL=", newSL,
            " | TP=", currentTP,
            " | retcode=", trade.ResultRetcode(),
            " | desc=", trade.ResultRetcodeDescription(),
            " | stopsLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
            " | freezeLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
   }
   else
   {
      Print("PositionModify OK | novoSL=", newSL, " | TP=", currentTP);
   }

   return ok;
}
