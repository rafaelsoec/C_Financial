//+------------------------------------------------------------------+
//|                                          FamilyMJ_MultiTF.mq5    |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>


CTrade trade;

struct MaximosMinimos
{
   double high;
   double low;
   double minOpen;
   double maxOpen;
   double minClose;
   double maxClose;
};

struct BordersOperation {
   double max;
   double min;
   double central;
   bool instantiated;
};

enum LEVEL{
   L1,
   L2,
   L3
 };
 
enum TYPE_NEGOCIATION{
   BUY,
   SELL,
   NONE
};

struct TimeframeConfig
{
   ENUM_TIMEFRAMES tf;
   int tfSeconds;
   int cciHandle;
   double multiplier;
   datetime lastBarTime;
   bool waitNewCandle;
   bool waitNewCandleTendency;
   bool waitNewCandleInversion;
   bool enableTendency;
   bool enableInversion;
   ulong magicNumber;
   TYPE_NEGOCIATION signalReversao;
   TYPE_NEGOCIATION signalTendencia;
   string label;
   MqlRates candleCandidate;
   int candleCandidateCounter;
   TYPE_NEGOCIATION candleCandidateTendency;
};

input double VOLUME = 0.10;
input double PERCENT_LOSS_PER_DAY = 2;
input double PERCENTUAL_MOVE_STOP = 30;
input double PROPORTION_TAKE_STOP = 2.0;
 bool ENABLE_TIMEFRAME_POSITION_TENDENCY = false; // Nao funcionou - o timeframe do candle nao influenciou as logicas de negociacao
input bool ENABLE_TIMEFRAME_MULTIPLIER = true;
input bool ENABLE_SWING_TRADE = true;
input bool ENABLE_REVERSION = true;
input bool ENABLE_TENDENCY = true;
input bool IS_TEST = false;
int NUMBER_MAX_ROBOT = 40;
double BALANCE = 0;
int QTD_CANDLES = 5;
ulong MAGIC_NUMBER = 8328138;
int MIN_COUNT_CANDIDATE_CANDLE = 5;


TimeframeConfig configs[];
string labelName = "CandleTimer";
MqlRates candles[];
int countOrders = 0;

//+------------------------------------------------------------------+
ulong GetMagicNumberByTimeframe(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return MAGIC_NUMBER + 5;
      case PERIOD_M15: return MAGIC_NUMBER + 15;
      case PERIOD_M30: return MAGIC_NUMBER + 30;
      case PERIOD_H1:  return MAGIC_NUMBER + 60;
      case PERIOD_H2:  return MAGIC_NUMBER + 120;
      case PERIOD_H3:  return MAGIC_NUMBER + 180;
      case PERIOD_H4:  return MAGIC_NUMBER + 240;
      case PERIOD_D1:  return MAGIC_NUMBER + 1440;
      case PERIOD_W1:  return MAGIC_NUMBER + 30 * 1440;
      default:         return MAGIC_NUMBER;
   }
}


//+------------------------------------------------------------------+
void showComments(){
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   Comment(
         " Total de posições ativas: ", (countOrders), 
         " Saldo: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) + profit, 2),
         " Lucro Atual: ", DoubleToString(profit, 2),
         " Tempo de Candle: ", transformarCandleTime()
         );
}

double TimeframeToMultiplier(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return 1;
      case PERIOD_M15: return 1.5;
      case PERIOD_M30: return 2;
      case PERIOD_H1:  return 2.5;
      case PERIOD_H2:  return 3;
      case PERIOD_H3:  return 3.5;
      case PERIOD_H4:  return 4;
      case PERIOD_D1:  return 4.5;
      case PERIOD_W1:  return 5;
      default:         return 1;
   }
}

int TimeframeToSeconds(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return 5 * 60;
      case PERIOD_M15: return 15 * 60;
      case PERIOD_M30: return 30 * 60;
      case PERIOD_H1:  return 60 * 60;
      case PERIOD_H2:  return 2 * 60 * 60;
      case PERIOD_H3:  return 3 * 60 * 60;
      case PERIOD_H4:  return 4 * 60 * 60;
      case PERIOD_D1:  return 24 * 60 * 60;
      case PERIOD_W1:  return 30 * 24 * 60 * 60;
      default:         return 0;
   }
}

//+--- NAO FUNCIONOU ESSA IDEIA---------------------------------------------------------------+
bool TimeframeToEnablePosition(ENUM_TIMEFRAMES tf, bool tendency)
{
   switch(tf)
   {
      case PERIOD_M5: return true;
      case PERIOD_M15: return true;
      case PERIOD_M30: return true;
      case PERIOD_H1:  return true;
      case PERIOD_H2:  return  true;
      case PERIOD_H3:  return  true;
      case PERIOD_H4:  return true;
      case PERIOD_D1:  return true;
      case PERIOD_W1:  return true;
      default:         return true;
   }
}
//+------------------------------------------------------------------+
string TimeframeToLabel(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      default:         return "UNKNOWN";
   }
}
//+------------------------------------------------------------------+
bool IsManagedMagic(ulong magic)
{
   for(int i = 0; i < ArraySize(configs); i++)
   {
      if(configs[i].magicNumber == magic)
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
int OnInit()
{
   
   ENUM_TIMEFRAMES tfs[] = {  PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4, PERIOD_D1};

   ArrayResize(configs, ArraySize(tfs));

   for(int i = 0; i < ArraySize(tfs); i++)
   {
      configs[i].tf = tfs[i];
      configs[i].cciHandle = iCCI(_Symbol, tfs[i], 14, PRICE_TYPICAL);
      configs[i].lastBarTime = 0;
      configs[i].multiplier = TimeframeToMultiplier(tfs[i]);
      configs[i].waitNewCandle = false;
      configs[i].waitNewCandleTendency = false;
      configs[i].waitNewCandleInversion = false;
      configs[i].enableTendency = TimeframeToEnablePosition(tfs[i], true);
      configs[i].enableInversion = TimeframeToEnablePosition(tfs[i], false);
      configs[i].signalReversao = NONE;
      configs[i].signalTendencia = NONE;
      configs[i].magicNumber = GetMagicNumberByTimeframe(tfs[i]);
      configs[i].label = TimeframeToLabel(tfs[i]);
      configs[i].candleCandidateCounter = 0;
      configs[i].candleCandidateTendency = NONE;
      configs[i].tfSeconds = TimeframeToSeconds(tfs[i]);

      if(configs[i].cciHandle == INVALID_HANDLE)
      {
         Print("Erro ao criar handle do CCI para ", configs[i].label, ". Erro: ", GetLastError());
         return INIT_FAILED;
      }
   }

   Print("Family MJ MultiTF iniciado com sucesso.");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < ArraySize(configs); i++)
   {
      if(configs[i].cciHandle != INVALID_HANDLE)
         IndicatorRelease(configs[i].cciHandle);
   }
}
//+------------------------------------------------------------------+
void OnTick()
{
   if (IsNewDay()){ 
      BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   countOrders = PositionsTotal();
   if(countOrders > NUMBER_MAX_ROBOT)
      return;
      
   if(!IS_TEST) {
      showComments();
      if(!ENABLE_SWING_TRADE && !IsMarketOpenNow(_Symbol, 30)){
         closeAll();
         printf("%s Mercado fechado!", _Symbol);
         return; 
      }
      
      if(!CheckDailyMaxLoss(PERCENT_LOSS_PER_DAY, "USD ")) {
           printf("Perda maxima atingida.");
           closeAll();
           return;  
      }
   }
      
   if(PERCENTUAL_MOVE_STOP > 0)
     MoveStopPorPontos();

   for(int i = 0; i < ArraySize(configs); i++)  {
      if(!IS_TEST && MercadoLateral(configs[i].tf)) {
        Print("Mercado lateral - NÃO operar");
        return;
      }
      
      if(!GetLastClosedCandles(configs[i].tf, candles))
         return;
         

      if(IsNewBar(configs[i])) {
         configs[i].waitNewCandle = false;
         configs[i].waitNewCandleTendency = false;
         configs[i].waitNewCandleInversion = false;
         
         if(configs[i].candleCandidateCounter > 0){
            if(configs[i].candleCandidateCounter == MIN_COUNT_CANDIDATE_CANDLE) {
               if ((configs[i].candleCandidateTendency == BUY && IsBearish(candles[1])) || (configs[i].candleCandidateTendency == SELL && IsBullish(candles[1])) ) {
                  configs[i].candleCandidateCounter = 0;
               } else {
                  configs[i].candleCandidate = candles[1];
               }
            }
            configs[i].candleCandidateCounter--;
         }
      }
      
      CheckSignalAndTrade(configs[i]);
      if(!IS_TEST) {
         generateButtons(configs[i].signalReversao, configs[i].signalTendencia, configs[i].label, i + 1);
      }
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

bool IsMarketOpenNow(string symbol, int antecedencia_minutos = 0){
   datetime now = TimeCurrent();        // horário do servidor
   MqlDateTime dt;
   TimeToStruct(now, dt);
   ENUM_DAY_OF_WEEK day = (ENUM_DAY_OF_WEEK)dt.day_of_week;

   datetime check_time = now - antecedencia_minutos * 60;
   for(uint i = 0; i < 20; i++)  {
      datetime from_time, to_time;
      if(!SymbolInfoSessionTrade(symbol, day, i, from_time, to_time))
         break;  // Não há mais sessões

      MqlDateTime dta;
      TimeToStruct(from_time, dta);
      if(dta.year < 2000){
         return true;
      }
      
      if(from_time == 0 && to_time == 0)
         continue;

      // Verifica se check_time está DENTRO da sessão
      if(check_time >= from_time && check_time < to_time)
         return true;
   }

   return false;
}

void generateButtons(TYPE_NEGOCIATION signalReversao, TYPE_NEGOCIATION signalTendencia, string nome, int indice) {
   color cor = signalReversao == BUY ? clrGreen : (signalReversao == SELL ? clrRed : clrOrange);
   color corT = signalTendencia == BUY ? clrGreen : (signalTendencia == SELL ? clrRed : clrOrange);
   string sinal = signalReversao == BUY ? "Buy" : (signalReversao == SELL ? "Sell" : "");
   string sinalT = signalTendencia == BUY ? "Buy" : (signalTendencia == SELL ? "Sell" : "");

   createButton("btnButton_reversao" + EnumToString(signalReversao) + nome, 20, (550 - indice * 50), 200, 30, CORNER_LEFT_LOWER, 11, "Arial",  " Reversao " + sinal  + nome, clrWhite, cor, cor, false);
   createButton("btnButton_tendencia" + EnumToString(signalTendencia) + nome, 230, (550 - indice * 50), 200, 30, CORNER_LEFT_LOWER, 11, "Arial", " Tendencia " + sinalT + nome, clrWhite, corT, corT, false);
}

//+------------------------------------------------------------------+
bool IsNewDay()
{
   static datetime last_day = 0;
   datetime current_day = iTime(_Symbol, PERIOD_D1, 0);

   if(last_day != current_day)
   {
      last_day = current_day;
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
bool IsNewBar(TimeframeConfig &config)
{
   datetime currentBarTime = iTime(_Symbol, config.tf, 0);

   if(currentBarTime == 0)
      return false;

   if(config.lastBarTime == 0)
   {
      config.lastBarTime = currentBarTime;
      return false;
   }

   if(currentBarTime != config.lastBarTime)
   {
      config.lastBarTime = currentBarTime;
      return true;
   }

   return false;
}

void closeBuyOrSell(int position, ulong magicNumber){
   if(hasPositionOpenWithMagicNumber(position, magicNumber)){
      ulong ticket = PositionGetTicket(position);
      trade.PositionClose(ticket);
   }
   
   ulong ticket = OrderGetTicket(position);
   trade.OrderDelete(ticket);
}

void closeAll(){
   int total = PositionsTotal() - 1;
   for(int position = total; position >= 0; position--)  {
      closeBuyOrSell(position, MAGIC_NUMBER);
   }
}

bool hasPositionOpenWithMagicNumber(int position, ulong magicNumberRobot){
   if(hasPositionOpen(position)){
      ulong ticket = PositionGetTicket(position);
      PositionSelectByTicket(ticket);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      if(magicNumber == magicNumberRobot){
         return true;
      }
   }
   
   return false;
   
}

bool hasPositionOpen(int position){
    string symbol = PositionGetSymbol(position);
    if(PositionSelect(symbol) == true) {
      return true;       
    }
    
    return false;
}
//+------------------------------------------------------------------+
bool HasPositionForMagic(ulong magicNumber)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);

      if(symbol == _Symbol && magic == magicNumber)
         return true;
   }

   return false;
}
//+------------------------------------------------------------------+
bool IsBullish(const MqlRates &candle)
{
   return candle.close > candle.open;
}
//+------------------------------------------------------------------+
bool IsBearish(const MqlRates &candle)
{
   return candle.close < candle.open;
}
//+------------------------------------------------------------------+
bool GetLastClosedCandles(ENUM_TIMEFRAMES tf, MqlRates &rates[])
{
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, tf, 0, QTD_CANDLES, rates);
   if(copied < QTD_CANDLES)
   {
      Print("Erro ao copiar candles de ", TimeframeToLabel(tf), ". Copiados: ", copied, " Erro: ", GetLastError());
      return false;
   }

   return true;
}
//+------------------------------------------------------------------+
bool GetCCIValue(TimeframeConfig &config, double &cciBuffer[])
{
   ArraySetAsSeries(cciBuffer, true);

   int copied = CopyBuffer(config.cciHandle, 0, 1, QTD_CANDLES, cciBuffer);
   if(copied < QTD_CANDLES) {
      Print("Erro ao copiar buffer do CCI em ", config.label, ". Erro: ", GetLastError());
      return false;
   }

   return true;
}
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(stepVol <= 0.0)
      return volume;

   volume = MathMax(minVol, MathMin(maxVol, volume));
   volume = MathFloor(volume / stepVol) * stepVol;

   return NormalizeDouble(volume, 2);
}
//+------------------------------------------------------------------+


double GetCCITendencyValue(TimeframeConfig &config, double limit){
   int bearishCount = 0;
   int bullishCount = 0;
   double cciValue = 0.0;
   double cci[];

   if(!GetCCIValue(config, cci)) {
      return 0;
   }

   for(int i = 1; i < QTD_CANDLES ; i++) {
      if(cci[i] > cci[i-1])
         bearishCount++;
         
      if(cci[i] < cci[i-1])
         bullishCount++;
   }

   return bearishCount >= limit && bullishCount >= limit;
}
//+------------------------------------------------------------------+
void CheckSignalAndTrade(TimeframeConfig &config) {
   bool c1Bull = IsBullish(candles[0]);
   bool c2Bull = IsBullish(candles[1]);
   bool c3Bull = IsBullish(candles[2]);
   bool c4Bull = IsBullish(candles[3]);

   bool c1Bear = IsBearish(candles[0]);
   bool c2Bear = IsBearish(candles[1]);
   bool c3Bear = IsBearish(candles[2]);
   bool c4Bear = IsBearish(candles[3]);
   
   bool enableInversion = ENABLE_REVERSION && ((ENABLE_TIMEFRAME_POSITION_TENDENCY && config.enableInversion) || !ENABLE_TIMEFRAME_POSITION_TENDENCY);
   bool enableTendency = ENABLE_TENDENCY && ((ENABLE_TIMEFRAME_POSITION_TENDENCY && config.enableTendency) || !ENABLE_TIMEFRAME_POSITION_TENDENCY);
   
   int initialTendency = 0, finalTendency = 0;
   if(config.candleCandidateCounter <= 0) {
      initialTendency = getCandleTendecy(0, QTD_CANDLES, 3);  
      if(initialTendency == -1 && c2Bear && c1Bull && candles[0].close > candles[1].open){
         config.candleCandidate = candles[0];
         config.candleCandidateTendency = BUY;
         config.candleCandidateCounter = MIN_COUNT_CANDIDATE_CANDLE;
      } else  if(initialTendency == 1 && c2Bull && c1Bear && candles[0].close < candles[1].open){
         config.candleCandidate = candles[0];
         config.candleCandidateTendency = SELL;
         config.candleCandidateCounter = MIN_COUNT_CANDIDATE_CANDLE;
      }
   } else {
      if (config.candleCandidateCounter < 4) {
         double cciBuffer[];
         if(!GetCCIValue(config, cciBuffer)) {
            return;
         }
         
         double proporcaoTempo = 1.2;
         MaximosMinimos maxMin = getMinOrMax(0, MIN_COUNT_CANDIDATE_CANDLE);
         double newVolume = ENABLE_TIMEFRAME_MULTIPLIER ? VOLUME * config.multiplier : VOLUME; 
         if(enableInversion && !config.waitNewCandleInversion && cciBuffer[0] > 100 && c1Bear && c2Bull && candles[0].close < candles[1].open){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            
            double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
            double sl = calcPoints(maxMin.high, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
            
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toSell(ask, newVolume, sl, tp, "SELL_INVERSION" + config.label);
            if(ok) {
               config.signalReversao = SELL;
               config.waitNewCandleInversion = true;
               countOrders++;
               Print("Sell executado com sucesso em ", config.label);
            }
         } 
         else if(enableInversion && !config.waitNewCandleInversion && cciBuffer[0] < -100 && c1Bull && c2Bear && candles[0].close > candles[1].open){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            
            double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
            double sl = calcPoints(candles[1].low, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
      
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toBuy(bid, newVolume, sl, tp, "BUY_INVERSION" + config.label);
            if(ok) {
               config.signalReversao = BUY;
               config.waitNewCandleInversion = true;
               countOrders++;
               Print("BUY executado com sucesso em ", config.label);
            }
         } 
         else if(enableTendency && cciBuffer[0] > -110 &&  c1Bear && c2Bull && IsBullish(config.candleCandidate) && candles[0].close < config.candleCandidate.open){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
            double sl = calcPoints(maxMin.high, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
      
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toSell(ask, newVolume, sl, tp, "SELL_" + config.label);
            if(ok) {
               config.signalTendencia = SELL;
               config.candleCandidateCounter = 0;
               config.candleCandidateTendency = NONE;
               countOrders++;
               Print("Sell executado com sucesso em ", config.label);
            }
            
       } else if(enableTendency && cciBuffer[0] < 110 && c1Bull && c2Bear && IsBearish(config.candleCandidate) && candles[0].close > config.candleCandidate.open){
            int remainingSeconds = calcularCandleTime();
            if(remainingSeconds > config.tfSeconds / proporcaoTempo) {
               return ;
            }
            double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
            double sl = calcPoints(maxMin.low, candles[0].close);
            double tp = sl * PROPORTION_TAKE_STOP;
      
            if(candles[0].spread > sl)
               return;
      
            trade.SetExpertMagicNumber(config.magicNumber);
            bool ok = toBuy(bid, newVolume, sl, tp, "BUY_" + config.label);
            if(ok) {
               config.signalTendencia = BUY;
               config.candleCandidateCounter = 0;
               config.candleCandidateTendency = NONE;
               countOrders++;
               Print("BUY executado com sucesso em ", config.label);
            }
         }
      }
   }

}
//+------------------------------------------------------------------+
string CandleType(const MqlRates &candle)
{
   if(candle.close > candle.open) return "BUY";
   if(candle.close < candle.open) return "SELL";
   return "DOJI";
}
//+------------------------------------------------------------------+
double calcPoints(double val1, double val2, bool absValue = true)
{
   if(absValue)
      return MathAbs(val1 - val2) / _Point;
   else
      return (val1 - val2) / _Point;
}
BordersOperation normalizeTakeProfitAndStopLoss(double stopLoss, double takeProfit){
   BordersOperation borders;
   borders.min = 0;
   borders.max = 0; 
   
   // modificação para o indice dolar DOLAR_INDEX
   if(stopLoss != 0 || takeProfit != 0){
      if(_Digits == 3){
         borders.min = (stopLoss * 1000);
         borders.max = (takeProfit * 1000);  
      }else{
         borders.min = NormalizeDouble((stopLoss * _Point), _Digits);
         borders.max = NormalizeDouble((takeProfit * _Point), _Digits); 
      }
   }
   
   return borders;
}

bool toBuy(double price, double volume, double stopLoss, double takeProfit, string comment){
   BordersOperation borders = normalizeTakeProfitAndStopLoss(stopLoss, takeProfit);
   double stopLossNormalized = NormalizeDouble((price - borders.min), _Digits);
   double takeProfitNormalized = NormalizeDouble((price + borders.max), _Digits);
   double entry = NormalizeDouble(price,_Digits);
   return trade.Buy(volume, _Symbol, entry, stopLossNormalized, takeProfitNormalized, comment);
}

bool toSell(double price, double volume, double stopLoss, double takeProfit, string comment){
   BordersOperation borders = normalizeTakeProfitAndStopLoss(stopLoss, takeProfit);
   double stopLossNormalized = NormalizeDouble((price + borders.min), _Digits);
   double takeProfitNormalized = NormalizeDouble((price - borders.max), _Digits);  
   double entry = NormalizeDouble(price, _Digits);
   return trade.Sell(volume, _Symbol, entry, stopLossNormalized, takeProfitNormalized, comment); 
}
//+------------------------------------------------------------------+
MaximosMinimos getMinOrMax(int start, int end) {
   double high = 0;
   double low = 999999;
   double minClose = 999999;
   double minOpen = 999999;
   double maxClose = 0;
   double maxOpen = 0;
   MaximosMinimos maxMin;
   
   for(int i = start; i < end; i++) {
      if (candles[i].low < low) {
         low = candles[i].low;
      }
      if (candles[i].high > high) {
         high = candles[i].high;
      }
      if (candles[i].close < minClose) {
         minClose = candles[i].close;
      }
      if (candles[i].close > maxClose) {
         maxClose = candles[i].close;
      }
      if (candles[i].open < minOpen) {
         minOpen = candles[i].open;
      }
      if (candles[i].open > maxOpen) {
         maxOpen = candles[i].open;
      }
   }

   maxMin.low = low;
   maxMin.high = high;
   maxMin.minClose = minClose;
   maxMin.minOpen = minOpen;
   maxMin.maxClose = maxClose;
   maxMin.maxOpen = maxOpen;

   return maxMin;
   
}

double getBodyOrWick(MqlRates &candle, bool body) {
   double bodyCandle = calcPoints(candle.close, candle.open);
   if(body) {
      return bodyCandle;
   } 
   
   return MathAbs(bodyCandle - calcPoints(candle.high, candle.low));
}
//+------------------------------------------------------------------+
int getCandleTendecy(int start, int end, int limit) {
   int bearishCount345 = 0;
   int bullishCount345 = 0;
   int bearishCount = 0;
   int bullishCount = 0;
   int ehPavio = 0;
   int ehGap = 0;

   for(int i = start; i < end; i++) {
      if(i+1 < end ) {
         if(candles[i+1].open > candles[i].close)
            bearishCount++;

         if(candles[i+1].open < candles[i].close)
            bullishCount++;
            
         if(candles[i+1].open != candles[i].close && candles[i+1].close != candles[i].open)
            if(DetectarGap(candles[i], candles[i+1], 300)) {
               ehGap++;
               break;
            }
      }
      
      double bodyCandle = getBodyOrWick(candles[i], true);
      double wickCandle = getBodyOrWick(candles[i], false);
      if(bodyCandle < wickCandle)
         ehPavio++;
         
      if(IsBearish(candles[i]))
         bearishCount345++;
         
      if(IsBullish(candles[i]))
         bullishCount345++;
   }
      
   if(ehGap > 0)
      return 0;
   
   if (ehPavio >= limit) {
      return 0;
   }

   if(bearishCount345 > bullishCount345 && bearishCount > bullishCount && bearishCount >= limit){
      return -1;
   }
   else if(bullishCount345 > bearishCount345 && bullishCount > bearishCount && bullishCount >= limit) {
      return 1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Detecta gap entre candles                                        |
//+------------------------------------------------------------------+
bool DetectarGap(MqlRates &actualCandle, MqlRates &lastCandle, double points) {
   double highAtual = actualCandle.high;
   double lowAtual  = actualCandle.low;

   double highPrev = lastCandle.high;
   double lowPrev  = lastCandle.low;

   // Gap de alta
   double pointsGapAlta = calcPoints(lowAtual, highPrev);
   if(lowAtual > highPrev && pointsGapAlta > points)
      return true;

   // Gap de baixa
   double pointsGapBaixa = calcPoints(lowPrev, highAtual);
   if(highAtual < lowPrev && pointsGapAlta > points)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Move o Stop Loss por pontos                                      |
//| pontos = distância em pontos do preço atual                      |
//+------------------------------------------------------------------+
void MoveStopPorPontos()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol)
         continue;

      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(!IsManagedMagic(magic))
         continue;

      long type        = PositionGetInteger(POSITION_TYPE);
      double slAtual   = PositionGetDouble(POSITION_SL);
      double tpAtual   = PositionGetDouble(POSITION_TP);
      double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double novoSL;

      if (profit > 0) {
         double pontosTP = calcPoints(entry, tpAtual);
         double pontosMove = pontosTP  * PERCENTUAL_MOVE_STOP / 100;
         double pontosSL = calcPoints(slAtual, currentPrice);
         double pontosEntrada = calcPoints(entry, currentPrice);
         double pontosProtecao = pontosMove * PERCENTUAL_MOVE_STOP / 100;
         
         if(type == POSITION_TYPE_BUY ) {
            if (entry > slAtual) {
               if (pontosEntrada > pontosMove) {
                  novoSL = entry + (pontosProtecao * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", entry, " - BUY");
               }
            } else {
               if (pontosSL > pontosMove) {
                  novoSL = slAtual + (pontosProtecao * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", novoSL, " - BUY");
               }
            }
         }
   
         if(type == POSITION_TYPE_SELL) {
            if (entry < slAtual) {
               if (pontosEntrada > pontosMove) {
                  novoSL = entry - (pontosProtecao * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", entry, " - SELL");
               }
            } else {
               if (pontosSL > pontosMove) {
                  novoSL = slAtual - (pontosProtecao * point);
                  if(trade.PositionModify(ticket, novoSL, tpAtual))
                     Print("Stop movido - ", novoSL, " - SELL");
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
double calcPrice(double price, double points)
{
   return NormalizeDouble(price + points * _Point, _Digits);
}
//+------------------------------------------------------------------+
int calcularCandleTime() {
   datetime candleOpenTime = iTime(_Symbol, _Period, 0);
   int periodSeconds = PeriodSeconds(_Period);
   datetime candleCloseTime = candleOpenTime + periodSeconds;

   int remainingSeconds = (int)(candleCloseTime - TimeCurrent());

   if(remainingSeconds < 0)
      remainingSeconds = 0;
   
   return remainingSeconds;
}

string transformarCandleTime() {
   int remainingSeconds = calcularCandleTime();
   int minutes = remainingSeconds / 60;
   int seconds = remainingSeconds % 60;

   return StringFormat("%02d:%02d", minutes, seconds);
}


void createButton(string nameLine, int xx, int yy, int largura, int altura, int canto, int tamanho, string fonte, string text, long corTexto, long corFundo, long corBorda, bool oculto){
   ObjectCreate(ChartID(),nameLine,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,nameLine,OBJPROP_XDISTANCE,xx);
   ObjectSetInteger(0,nameLine,OBJPROP_YDISTANCE, yy);
   ObjectSetInteger(0,nameLine,OBJPROP_XSIZE, largura);
   ObjectSetInteger(0,nameLine,OBJPROP_YSIZE, altura);
   ObjectSetInteger(0,nameLine,OBJPROP_CORNER, canto);
   ObjectSetInteger(0,nameLine,OBJPROP_FONTSIZE, tamanho);
   ObjectSetString(0,nameLine,OBJPROP_FONT, fonte);
   ObjectSetString(0,nameLine,OBJPROP_TEXT, text);
   ObjectSetInteger(0,nameLine,OBJPROP_COLOR, corTexto);
   ObjectSetInteger(0,nameLine,OBJPROP_BGCOLOR, corFundo);
   ObjectSetInteger(0,nameLine,OBJPROP_BORDER_COLOR, corBorda);
}

//+------------------------------------------------------------------+
//| Retorna:                                                         |
//|  1  = Cruzamento para cima (compra)                              |
//| -1  = Cruzamento para baixo (venda)                              |
//|  0  = Nenhum cruzamento                                          |
//+------------------------------------------------------------------+
int CruzamentoMedias(ENUM_TIMEFRAMES timeframe,
                     int periodoRapido,
                     int periodoLento,
                     ENUM_MA_METHOD metodo = MODE_EMA,
                     ENUM_APPLIED_PRICE preco = PRICE_CLOSE)
{
   // Buffers
   double maRapida[2];
   double maLenta[2];

   // Handles das médias
   int handleRapida = iMA(_Symbol, timeframe, periodoRapido, 1, metodo, preco);
   int handleLenta  = iMA(_Symbol, timeframe, periodoLento, 1, metodo, preco);

   if(handleRapida == INVALID_HANDLE || handleLenta == INVALID_HANDLE)
      return 0;

   // Copiar os últimos 2 valores
   if(CopyBuffer(handleRapida, 0, 0, 2, maRapida) <= 0)
      return 0;

   if(CopyBuffer(handleLenta, 0, 0, 2, maLenta) <= 0)
      return 0;

   // Valores atuais e anteriores
   double rapidaAtual   = maRapida[0];
   double rapidaAnterior= maRapida[1];

   double lentaAtual    = maLenta[0];
   double lentaAnterior = maLenta[1];

   // Cruzamento para cima
   if(rapidaAnterior < lentaAnterior && rapidaAtual > lentaAtual)
      return 1;

   // Cruzamento para baixo
   if(rapidaAnterior > lentaAnterior && rapidaAtual < lentaAtual)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Detecta mercado lateral                                          |
//| Retorna true = lateral                                           |
//+------------------------------------------------------------------+
bool MercadoLateral(
                    ENUM_TIMEFRAMES timeframe,
                    int periodoMA = 50,
                    int periodoADX = 14,
                    double limiteADX = 20.0,
                    double limiteInclinacao = 0.0001)
{
   double ma[3];
   double adx[1];

   // Handle MA
   int handleMA = iMA(_Symbol, timeframe, periodoMA, 0, MODE_EMA, PRICE_CLOSE);

   // Handle ADX
   int handleADX = iADX(_Symbol, timeframe, periodoADX);

   if(handleMA == INVALID_HANDLE || handleADX == INVALID_HANDLE)
      return false;

   // Pegando últimos 3 valores da média
   if(CopyBuffer(handleMA, 0, 0, 3, ma) <= 0)
      return false;

   // Pegando valor atual do ADX
   if(CopyBuffer(handleADX, 0, 0, 1, adx) <= 0)
      return false;

   // Inclinação da média (diferença simples)
   double inclinacao = ma[0] - ma[2];

   // Condições de lateralização
   bool maReta = MathAbs(inclinacao) < limiteInclinacao;
   bool adxFraco = adx[0] < limiteADX;

   if(maReta && adxFraco)
      return true;

   return false;
}
