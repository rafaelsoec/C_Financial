//+------------------------------------------------------------------+
//|                                          FamilyMJ_MultiTF.mq5    |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

struct BordersOperation {
   double max;
   double min;
   double central;
   bool instantiated;
};

struct RegiaoExtremo{
   double precoMin;
   double precoMax;
   double precoMedio;

   int quantidade;
   int primeiroShift;
   int ultimoShift;

   datetime primeiroTempo;
   datetime ultimoTempo;
};

struct LossTrade {
   datetime closeTime;
   double profit;
   ENUM_DEAL_TYPE type;
   double price;
};

enum VOLATILITY {
   VERY_LOW,
   LOW,
   MEDIUM,
   HIGH,
   VERY_HIGH
};

enum LOSS_TREND {
   LOSS_NONE,
   LOSS_BUY,
   LOSS_SELL,
   LOSS_BALANCED
};

enum MOVE_STOP_TYPE{
   MOVE_STOP_TRAIL = 1,
   MOVE_STOP_10    = 10,
   MOVE_STOP_20    = 20,
   MOVE_STOP_30    = 30,
   MOVE_STOP_40    = 40,
   MOVE_STOP_50    = 50,
   MOVE_STOP_60    = 60,
   MOVE_STOP_70    = 70,
   MOVE_STOP_NONE  = 0
 };
 
enum MOVING_AVERAGE_TYPE {
   MV_9   = 9,
   MV_21   = 21,
   MV_50   = 50,
   MV_80   = 80,
   MV_200   = 200,
   MV_400   = 400
};
 
enum ATR_TYPE {
   ATR_0   = 0,
   ATR_0_5 = 5,
   ATR_1   = 10,
   ATR_1_5 = 15,
   ATR_2   = 20,
   ATR_2_5 = 25,
   ATR_3   = 30,
   ATR_3_5 = 35,
   ATR_4   = 40,
   ATR_4_5 = 45,
   ATR_5   = 50
};
 
enum LEVEL{
   L1,
   L2,
   L3
 };
 
enum TypeNegotiation{
   BUY,
   SELL,
   NONE
};

enum VolumeLevel
{
   VOLUME_LOW,
   VOLUME_NORMAL,
   VOLUME_HIGH
};

struct TimeFrameCandle {
   bool win;
   bool updated;
   TypeNegotiation type;
   double volume;
   double open;
   double stop;
   double take;
   datetime time;
};

struct TimeFrameRobot {
   int maxRobots;
   int counter;
   int counterPositions;
   bool inLoss;
   bool waitNewCandle;
   TimeFrameCandle historic[10];
};

CTrade trade;
struct TimeframeConfig
{
   ENUM_TIMEFRAMES tf;
   int tfSeconds;
   int cciHandle;
   double multiplier;
   datetime lastBarTime;
   TimeFrameRobot robotTendency;
   TimeFrameRobot robotAverageTendency;
   TimeFrameRobot robotEngolfoTendency;
   TimeFrameRobot robotCrossTendency;
   ulong magicNumber;
   double atr[15];
   double movingAverage[15];
   double movingAverage21[15];
   double movingAverage50[15];
   double adx[15];
   double adxMinus[15];
   double adxPlus[15];
   double cci[15];
   BordersOperation bordas;
   TypeNegotiation adxTendency;
   TypeNegotiation adxPlusTendency;
   TypeNegotiation adxMinusTendency;
   string label;
   MqlRates candles[];
};

struct MaximosMinimos
{
   double high;
   double low;
   double minOpen;
   double maxOpen;
   double minClose;
   double maxClose;
};

input int QTD_CANDLES = 5;
input double VOLUME = 0.01;
 ATR_TYPE ATR_MINIMUM = ATR_0_5;
input double PROPORTION_TAKE_STOP = 2;
input bool ENABLE_CRUZAMENTO = true;
input bool ENABLE_ENGOLFO = true;
input bool ENABLE_MEDIAS = true;
input bool ENABLE_TENDENCIA = true;
 bool ENABLE_TIMEFRAME_MULTIPLIER = false;
input int NUMBER_MAX_ROBOT = 2;
input ulong MAGIC_NUMBER = 97889902933;

TimeframeConfig configs[];
ENUM_TIMEFRAMES tfs[] = { PERIOD_M30 };
int QTD_ITEMS = 15;

//
//+------------------------------------------------------------------+
ulong GetMagicNumberByTimeframe(ENUM_TIMEFRAMES tf) {
   switch(tf)  {
      default:         return MAGIC_NUMBER;
   }
}

double TimeframeToMultiplier(ENUM_TIMEFRAMES tf){
   switch(tf) {
      case PERIOD_M5: return 1;
      case PERIOD_M10: return 1;
      case PERIOD_M15: return 1.2;
      case PERIOD_M20: return 1.5;
      case PERIOD_M30: return 2;
      case PERIOD_H1:  return 2.5;
      case PERIOD_H2:  return 3;
      case PERIOD_H3:  return 3.5;
      case PERIOD_H4:  return 4;
      case PERIOD_H6:  return 4.5;
      case PERIOD_H8:  return 5;
      case PERIOD_D1:  return 5.5;
      case PERIOD_W1:  return 6;
      case PERIOD_MN1:  return 6.5;
      default:         return 1;
   }
}

int TimeframeToSeconds(ENUM_TIMEFRAMES tf) {
   return PeriodSeconds(tf);
}

//+------------------------------------------------------------------+
string TimeframeToLabel(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5: return "M5";
      case PERIOD_M10: return "M10";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1:  return "MN1";
      default:         return "UNKNOWN";
   }
}

ENUM_TIMEFRAMES getTfByComment(string tfComment) {
   for(int i = 0; i < ArraySize(configs); i++) {
      string tfLabel = "TENDENCY_" + TimeframeToLabel(configs[i].tf);
      if(StringFind(tfComment, tfLabel) >= 0) {
         return  configs[i].tf;
      }
   }
   
   return PERIOD_MN1;
}
//+------------------------------------------------------------------+
bool IsManagedMagic(ulong magic) {
   for(int i = 0; i < ArraySize(configs); i++) {
      if(configs[i].magicNumber == magic)
         return true;
   }
   return false;
}


void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
}

//+------------------------------------------------------------------+
int OnInit() { 
   ArrayResize(configs, ArraySize(tfs));
   for(int i = 0; i < ArraySize(tfs); i++) {
      configs[i].tf = tfs[i];
      configs[i].lastBarTime = 0;
      configs[i].multiplier = TimeframeToMultiplier(tfs[i]);
      configs[i].magicNumber = GetMagicNumberByTimeframe(tfs[i]);
      configs[i].label = TimeframeToLabel(tfs[i]);
      configs[i].tfSeconds = TimeframeToSeconds(tfs[i]);
      configs[i].bordas.max = 9999999;
      configs[i].bordas.min = 0;
      
      iniciarRobos(configs[i].robotEngolfoTendency);
      iniciarRobos(configs[i].robotCrossTendency);
      iniciarRobos(configs[i].robotAverageTendency);
      iniciarRobos(configs[i].robotTendency);
   }

   Print("Family MJ MultiTF iniciado com sucesso.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for(int i = 0; i < ArraySize(configs); i++) {
      if(configs[i].cciHandle != INVALID_HANDLE)
         IndicatorRelease(configs[i].cciHandle);
   }
}

//+------------------------------------------------------------------+
void OnTick() {
   for(int i = 0; i < ArraySize(configs); i++)  {
      if(!GetLastClosedCandles(configs[i])) {
         printf("Candles Nao Recuperados - " + EnumToString(configs[i].tf));
         return;
      } 
      
      if (!GetMovingAverage(configs[i], MV_9, configs[i].movingAverage)) {
         printf("Media 9 Nao Recuperada - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetMovingAverage(configs[i], MV_21, configs[i].movingAverage21)) {
         printf("Media 21 Nao Recuperada - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetMovingAverage(configs[i], MV_50, configs[i].movingAverage50)) {
         printf("Media 50 Nao Recuperada - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if (!GetAdx(configs[i])) {
         printf("ADX Nao Recuperado - " + EnumToString(configs[i].tf));
         return;
      }   
      
      if(IsNewBar(configs[i])) {
         int total = PositionsTotal();
         resetarRobo(configs[i].robotEngolfoTendency, total);
         resetarRobo(configs[i].robotAverageTendency, total);
         resetarRobo(configs[i].robotCrossTendency, total);
         resetarRobo(configs[i].robotTendency, total);
         DesenharMaximoMinimoMaisTocados(configs[i], 15, 10);
      }
      
      if (ENABLE_ENGOLFO) {
         executarEngolfo(configs[i]);
      }
      
      if (ENABLE_MEDIAS) {
         executarMedias(configs[i]);
      }
      
      if (ENABLE_CRUZAMENTO) {
         executarCruzamento(configs[i]);
      }
      
      if (ENABLE_TENDENCIA) {
         executarTendencia(configs[i]);
      }
 
   }
} 

void executarEngolfo(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   if (config.robotEngolfoTendency.maxRobots <= 0){
      return;
   }
   
   if (config.robotEngolfoTendency.waitNewCandle){
      return;
   }
   
   if (config.robotEngolfoTendency.inLoss){
    // return;
   }
   
   if (IsMaxRobots()){
      return;
   }
   
   string comentario = "robotEngolfoTendency_" + EnumToString(config.tf); 
   double lastOpen = config.candles[2].open;
   if(CandlesEmparelhados(config.tf, 3, 200)) {
      double stop = CalcularPontos(precoAtual, config.candles[2].close);
      double take = stop * PROPORTION_TAKE_STOP;
      if (precoAtual > lastOpen && precoAtual > config.movingAverage21[0] && verificarBordas(config, BUY)) {
         ExecutarNegociacao(BUY, getVolumeAtr(config), stop, take, comentario, config.robotEngolfoTendency);
      } else if (precoAtual < lastOpen && precoAtual < config.movingAverage21[0] && verificarBordas(config, SELL)) {
         ExecutarNegociacao(SELL, getVolumeAtr(config), stop, take, comentario, config.robotEngolfoTendency);
      }
   }
}

void executarCruzamento(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   if (config.robotCrossTendency.maxRobots <= 0){
      return;
   }
   
   if (config.robotCrossTendency.waitNewCandle){
      return;
   }
   
   if (config.robotCrossTendency.inLoss){
  //    return;
   }
   
   if (IsMaxRobots()){
      return;
   }
   
   string comentario = "robotCrossTendency_" + EnumToString(config.tf);
   if(config.adxMinusTendency != NONE  && config.adxPlusTendency != NONE && config.adxMinusTendency != config.adxPlusTendency) {
      if (IsBearish(config.candles[0])  && config.adxMinusTendency == BUY && config.adxMinus[0] > config.adxPlus[0] && config.adxMinus[4] < config.adxPlus[4]
            && verificarBordas(config, SELL) 
            && ((config.movingAverage21[0] > precoAtual && config.movingAverage[0] > precoAtual))) {
         double stop =  CalcularPontos(config.candles[2].high, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(SELL, VOLUME, stop, take, comentario, config.robotCrossTendency);
      }
      
      if (IsBullish(config.candles[0]) && config.adxMinusTendency == SELL  && config.adxMinus[0] < config.adxPlus[0]  && config.adxMinus[4] > config.adxPlus[4]
            && verificarBordas(config, BUY) 
            && ((config.movingAverage21[0] < precoAtual && config.movingAverage[0] < precoAtual))) {
         double stop =  CalcularPontos(config.candles[2].low, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(BUY, VOLUME, stop, take, comentario, config.robotCrossTendency);
      }
   
   }
}

void executarMedias(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   if (config.robotAverageTendency.maxRobots <= 0){
      return;
   }
   
   if (config.robotAverageTendency.waitNewCandle){
      return;
   }
   
   if (config.robotAverageTendency.inLoss){
  //    return;
   }
   
   if (IsMaxRobots()){
      return;
   }
   
   string comentario = "robotAverageTendency_" + EnumToString(config.tf);
   if (IsBearish(config.candles[1]) && IsBearish(config.candles[0]) && config.movingAverage[2] > precoAtual 
      && verificarBordas(config, SELL) && config.movingAverage21[0] > precoAtual) {
      double stop =  CalcularPontos(config.candles[1].high, precoAtual);
      double take = stop * PROPORTION_TAKE_STOP;
      ExecutarNegociacao(SELL, getVolumeAtr(config), stop, take, comentario, config.robotAverageTendency);
   } else if (IsBullish(config.candles[1]) && IsBullish(config.candles[0]) && config.movingAverage[0] < precoAtual 
      && verificarBordas(config, BUY) && config.movingAverage21[0] < precoAtual) {
      double stop =  CalcularPontos(config.candles[1].low, precoAtual);
      double take = stop * PROPORTION_TAKE_STOP;
      ExecutarNegociacao(BUY, getVolumeAtr(config), stop, take, comentario, config.robotAverageTendency);
   }
}

void executarTendencia(TimeframeConfig &config) {
   double precoAtual = config.candles[0].close;
   if (config.robotTendency.maxRobots <= 0){
      return;
   }
   
   if (config.robotTendency.waitNewCandle){
      return;
   }
   
   if (config.robotTendency.inLoss){
  //    return;
   }
   
   if (IsMaxRobots()){
      return;
   }
   
   string comentario = "robotTendency_" + EnumToString(config.tf);
   int initialTendency = getCandleTendecy(1, QTD_CANDLES, 1, true, 0, config);
   bool diff =  MathAbs(config.adxPlus[0] - config.adxMinus[0])  > 10;
   
   if(initialTendency == -1  && diff){
      if (config.movingAverage[1] > precoAtual && config.movingAverage[2] > precoAtual 
         && config.adxMinus[0] > config.adxPlus[0] && verificarBordas(config, SELL)) {
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES, config);
         double stop =  CalcularPontos(maxMin.high, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(SELL, getVolumeAtr(config), stop, take, comentario, config.robotTendency);
      }
   } else  if(initialTendency == 1 && diff ){
      if (config.movingAverage[1] < precoAtual && config.movingAverage[2] < precoAtual 
         && config.adxPlus[0] > config.adxMinus[0] && verificarBordas(config, BUY)) {
         MaximosMinimos maxMin = getMinOrMax(1, QTD_CANDLES, config);
         double stop =  CalcularPontos(maxMin.low, precoAtual);
         double take = stop * PROPORTION_TAKE_STOP;
         ExecutarNegociacao(BUY, getVolumeAtr(config), stop, take, comentario, config.robotTendency);
      }
   }
}

bool ExecutarNegociacao(TypeNegotiation tipoNegociacao, double volume,  double pontosStop, double pontosTake, string comentario, TimeFrameRobot &robot) {
   if(pontosStop <= 0 || pontosTake <= 0)
      return false;
      
   double preco = 0;
   double stop = 0;
   double take = 0;
   bool ordemExecutada = false;
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   if(tipoNegociacao == BUY) {
      preco = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      stop = preco - (pontosStop * _Point);
      take = preco + (pontosTake * _Point);

      stop = NormalizeDouble(stop, _Digits);
      take = NormalizeDouble(take, _Digits);

      if(!trade.Buy(volume,  _Symbol,  preco, stop,  take, comentario)) {
         Print("Erro ao executar compra: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         return false;
      }
      ordemExecutada = true;
   } else if(tipoNegociacao == SELL) {
      preco = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      stop = preco + (pontosStop * _Point);
      take = preco - (pontosTake * _Point);

      stop = NormalizeDouble(stop, _Digits);
      take = NormalizeDouble(take, _Digits);

      if(!trade.Sell(volume,  _Symbol,  preco, stop, take, comentario)) {
         Print("Erro ao executar venda: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         return false;
      }
      ordemExecutada = true;
   }

   if (ordemExecutada && robot.counter >= 0) {
      if (robot.counter >= 5) {
         robot.inLoss = verificarPerdaRobo(robot, 5, preco);
      } 
      
      if (robot.counter >= ArraySize(robot.historic)) {
         robot.counter = 0;
      } 
      
      robot.waitNewCandle = true;
      robot.maxRobots--;
      robot.historic[robot.counter].volume = volume;
      robot.historic[robot.counter].time = TimeCurrent();
      robot.historic[robot.counter].type = tipoNegociacao;
      robot.historic[robot.counter].take = take;
      robot.historic[robot.counter].stop = stop;
      robot.counterPositions++;
      robot.counter++;
   }

   return false;
}

void resetarRobo(TimeFrameRobot &robot, int totalPositions) {
   robot.waitNewCandle = false;
   
   if (totalPositions == 0 && robot.maxRobots <= 0) {
      robot.maxRobots = NUMBER_MAX_ROBOT;
   }
}

double getVolumeAtr(TimeframeConfig &config) {
   double tendenciaExtrapolada = IsTrendSaturated(config);
   if (tendenciaExtrapolada == 0) {
      return 0;
   }
   
   return NormalizeDouble(VOLUME * tendenciaExtrapolada, _Digits);
}

void DesenharLinhaHorizontal(string label, double ponto, color cor) {
   string nome = label;

   // Se já existir, apenas atualiza o preço e a cor
   if(ObjectFind(0, nome) >= 0) {
      ObjectSetDouble(0, nome, OBJPROP_PRICE, ponto);
      ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
      return;
   }

   // Cria a linha
   if(ObjectCreate(0, nome, OBJ_HLINE, 0, 0, ponto)) {
      ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
      ObjectSetInteger(0, nome, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_SOLID);
   }

   ChartRedraw();
}

bool verificarBordas(TimeframeConfig &config, TypeNegotiation type) {
   double precoAtual = config.candles[0].close;
   if(config.bordas.min == 0) {
      return true;
   }
   
   if (type == BUY && (precoAtual >= config.bordas.max)) {
      return true;
   }
   
   if (type == SELL && (precoAtual <= config.bordas.min)) {
      return true;
   }
   
   return false;
}

bool verificarPerdaRobo(TimeFrameRobot &robot, int max, double precoAtual) {
   int counter = 0;
   if (robot.counter < max || precoAtual == 0) {
      return false;
   }
   
   for (int i = 0; i < robot.counter; i++) {
      if (!robot.historic[i].updated) {
         if (precoAtual >= robot.historic[i].take && robot.historic[i].type == BUY) {
            robot.historic[i].updated = true;
            robot.historic[i].win = true;
         } else if (precoAtual <= robot.historic[i].take && robot.historic[i].type == SELL) {
            robot.historic[i].updated = true;
            robot.historic[i].win = true;
         }
         
         if (precoAtual >= robot.historic[i].stop && robot.historic[i].type == SELL) {
            robot.historic[i].updated = true;
            robot.historic[i].win = false;
         } else if (precoAtual <= robot.historic[i].stop && robot.historic[i].type == BUY) {
            robot.historic[i].updated = true;
            robot.historic[i].win = false;
         }
      }
      
      if (!robot.historic[i].win && robot.historic[i].updated) {
         counter++;
      }
   }
   
   return counter >= max;
}

void iniciarRobos(TimeFrameRobot &robot) {
   robot.inLoss = false;
   robot.counter = 0;
   robot.counterPositions = 0;
   robot.waitNewCandle = false;
   robot.maxRobots = NUMBER_MAX_ROBOT;
   
   for(int j = 0; j < ArraySize(robot.historic); j++) {
      robot.historic[j].type = NONE; 
      robot.historic[j].win = false;
      robot.historic[j].updated = false;
   }  
}

MaximosMinimos getMinOrMax(int start, int end, TimeframeConfig &config) {
   double high = 0;
   double low = 999999;
   double minClose = 999999;
   double minOpen = 999999;
   double maxClose = 0;
   double maxOpen = 0;
   MaximosMinimos maxMin;
   
   for(int i = start; i <= end; i++) {
      if (config.candles[i].low < low) {
         low = config.candles[i].low;
      }
      if (config.candles[i].high > high) {
         high = config.candles[i].high;
      }
      if (config.candles[i].close < minClose) {
         minClose = config.candles[i].close;
      }
      if (config.candles[i].close > maxClose) {
         maxClose = config.candles[i].close;
      }
      if (config.candles[i].open < minOpen) {
         minOpen = config.candles[i].open;
      }
      if (config.candles[i].open > maxOpen) {
         maxOpen = config.candles[i].open;
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

double CalcularPontos(double preco1, double preco2, bool isAbs = true) {
   if (isAbs) {
      return MathRound(MathAbs((preco1 - preco2) / _Point));
   }
   
   return MathRound((preco1 - preco2) / _Point);
}

bool CandlesEmparelhados(ENUM_TIMEFRAMES tf, int n, int distanciaMaximaPontos) {
   if(n < 2)
      return false;

   for(int i = n; i >= 1; i--){
      double open  = iOpen(_Symbol, tf, i);
      double close = iClose(_Symbol, tf, i);
      double high  = iHigh(_Symbol, tf, i);
      double low   = iLow(_Symbol, tf, i);

      // =====================================================
      // VERIFICA O TAMANHO DO CORPO
      // =====================================================

      double corpo = MathAbs(close - open);
      double amplitude = high - low;

      if(amplitude <= 0)
         return false;

      // Corpo precisa ter pelo menos 60% da amplitude
      if((corpo / amplitude) < 0.60)
         return false;

      // =====================================================
      // VERIFICA EMPARELHAMENTO
      // =====================================================

      if(i > 1)
      {
         double openProximo = iOpen(_Symbol, tf, i - 1);

         int distancia = (int)MathRound(
            MathAbs(close - openProximo) / _Point
         );

         if(distancia > distanciaMaximaPontos)
            return false;

         // =================================================
         // VERIFICA SE OS CANDLES ESTÃO AO CONTRÁRIO
         // =================================================

         bool candleAtualAlta = close > open;
         bool candleProximoAlta = iClose(_Symbol, tf, i - 1) >
                                  iOpen(_Symbol, tf, i - 1);

         // Os dois não podem ter a mesma direção
         if(candleAtualAlta == candleProximoAlta)
            return false;
      }
   }

   return true;
}

bool IsBullish(const MqlRates &candle) {
   return candle.close > candle.open;
}

//+------------------------------------------------------------------+
bool IsBearish(const MqlRates &candle) {
   return candle.close < candle.open;
}

//+------------------------------------------------------------------+
bool IsNewBar(TimeframeConfig &config) {
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

bool GetLastClosedCandles(TimeframeConfig &config) {
   ENUM_TIMEFRAMES tf = config.tf;
   ArraySetAsSeries(config.candles, true);

   int copied = CopyRates(_Symbol, tf, 0, QTD_CANDLES * 2, config.candles);
   if(copied < QTD_CANDLES) {
      Print("Erro ao copiar candles de ", TimeframeToLabel(tf), ". Copiados: ", copied, " Erro: ", GetLastError());
      return false;
   }

   return true;
}

bool GetAdx(TimeframeConfig &config) { 
   int handleADX = iADX(_Symbol, config.tf, 14);
   if(handleADX == INVALID_HANDLE)
      return false;

   if(CopyBuffer(handleADX, 0, 0, QTD_ITEMS, config.adx) <= 0  
      ||  CopyBuffer(handleADX, 2, 0, QTD_ITEMS, config.adxMinus) <= 0 
      || CopyBuffer(handleADX, 1, 0, QTD_ITEMS, config.adxPlus) <= 0)
      return false;
      
   ArrayReverse(config.adx);
   ArrayReverse(config.adxMinus);
   ArrayReverse(config.adxPlus);
   
   for (int i = 0; i < 3; i++) {
      config.adxTendency = ValidateListTendency(config.adx);
      config.adxMinusTendency = ValidateListTendency(config.adxMinus);
      config.adxPlusTendency = ValidateListTendency(config.adxPlus);
   }   
       
       
   return true;
}

TypeNegotiation ValidateListTendency(double &values[]) {
   int buyCount = 0, sellCount = 0, counter = 3;

   for (int i = counter+1; i > 0; i--) {
      if (values[i] > values[i-1]) {
         sellCount++;
      } else {
         buyCount++;
      }
   }  
   
   if (buyCount >= counter || (sellCount >= counter && values[0] > values[counter])) {
      return BUY;
   } 
   
   if (sellCount >= counter || (buyCount >= counter && values[0] < values[counter])) {
      return SELL;
   }
   
   return NONE;
}

double getBodyOrWick(MqlRates &candle, bool body) {
   double bodyCandle = CalcularPontos(candle.close, candle.open);
   if(body) {
      return bodyCandle;
   } 
   
   return MathAbs(bodyCandle - CalcularPontos(candle.high, candle.low));
}

int getCandleTendecy(int start, int end, int limit, bool ignoreType, double bodySize, TimeframeConfig &config) {
   int bearishCount = 0;
   int bullishCount = 0;
   int low = 0;
   int high = 0;
   for(int i = start; i < end; i++) {
      double body = getBodyOrWick(config.candles[i], true);
      double wick = getBodyOrWick(config.candles[i], false);
      
      if(i+1 < end ) {
         if(config.candles[i+1].open > config.candles[i].close 
            && body > wick * bodySize  / 100
            && config.candles[i+1].high > config.candles[i].high 
            && (ignoreType || (IsBearish(config.candles[i+1]) && IsBearish(config.candles[i])))
            ) {
            bearishCount++;
         }

         if(config.candles[i+1].open < config.candles[i].close 
            && body > wick * bodySize / 100
            && config.candles[i+1].low < config.candles[i].low 
            && (ignoreType || (IsBullish(config.candles[i+1]) && IsBullish(config.candles[i])))
           ) {
            bullishCount++;
         }
      }
   }

   if(bearishCount > bullishCount && bearishCount >= limit){
      return -1;
   }
   else if(bullishCount > bearishCount && bullishCount >= limit) {
      return 1;
   }
   
   return 0;
}

bool GetMovingAverage(TimeframeConfig &config, int period, double &buffer[]) {   
   // Handle MA
   int handleMA = iMA(_Symbol, config.tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handleMA == INVALID_HANDLE)
      return false;

   if(CopyBuffer(handleMA, 0, 0, QTD_ITEMS, buffer) <= 0)
      return false;
   
   ArrayReverse(buffer);
   return true;
}

bool IsMaxRobots() {
   if (NUMBER_MAX_ROBOT == 0) {
      return false;
   }

   int count = 0;
   if (ENABLE_CRUZAMENTO) {
      count++;
   }
   if (ENABLE_ENGOLFO) {
      count++;
   }
   if (ENABLE_MEDIAS) {
      count++;
   }
   if (ENABLE_TENDENCIA) {
      count++;
   }
   
   return PositionsTotal() >= NUMBER_MAX_ROBOT * count;
}

void DesenharMaximoMinimoMaisTocados(TimeframeConfig &config, int qtdCandles, int n){
   if(qtdCandles < 5)
      return;
      
      
   int min = 5;
   // =========================================================
   // PROCURA OS 3 ÚLTIMOS TOPOS
   // =========================================================

   double topos[5];
   int qtdTopos = 0;
   double fundos[5];
   int qtdFundos = 0;
   ENUM_TIMEFRAMES tf = config.tf;
   for(int i = 1; i < qtdCandles - 1 && qtdTopos < min; i++)
   {
      double openAnterior  = iOpen(_Symbol, tf, i + 1);
      double closeAnterior = iClose(_Symbol, tf, i + 1);

      double openAtual  = iOpen(_Symbol, tf, i);
      double closeAtual = iClose(_Symbol, tf, i);

      double openPosterior  = iOpen(_Symbol, tf, i - 1);
      double closePosterior = iClose(_Symbol, tf, i - 1);

      double topoAnterior  = MathMax(openAnterior, closeAnterior);
      double topoAtual     = MathMax(openAtual, closeAtual);
      double topoPosterior = MathMax(openPosterior, closePosterior);

      if(topoAtual > topoAnterior && topoAtual > topoPosterior)
      {
         topos[qtdTopos] = topoAtual;
         qtdTopos++;
      }
   }

   // =========================================================
   // PROCURA OS 3 ÚLTIMOS FUNDOS
   // =========================================================

   for(int i = 1; i < qtdCandles - 1 && qtdFundos < min; i++)
   {
      double openAnterior  = iOpen(_Symbol, tf, i + 1);
      double closeAnterior = iClose(_Symbol, tf, i + 1);

      double openAtual  = iOpen(_Symbol, tf, i);
      double closeAtual = iClose(_Symbol, tf, i);

      double openPosterior  = iOpen(_Symbol, tf, i - 1);
      double closePosterior = iClose(_Symbol, tf, i - 1);

      double fundoAnterior  = MathMin(openAnterior, closeAnterior);
      double fundoAtual     = MathMin(openAtual, closeAtual);
      double fundoPosterior = MathMin(openPosterior, closePosterior);

      if(fundoAtual < fundoAnterior && fundoAtual < fundoPosterior)
      {
         fundos[qtdFundos] = fundoAtual;
         qtdFundos++;
      }
   }

   // =========================================================
   // ENCONTRA O TOPO MAIS TOCADO
   // =========================================================

   double melhorTopo = 0;
   int maiorQuantidadeTopo = 0;

   for(int i = 0; i < qtdTopos; i++)
   {
      int quantidade = 0;

      for(int j = 0; j < qtdCandles; j++)
      {
         double open  = iOpen(_Symbol, tf, j);
         double close = iClose(_Symbol, tf, j);

         if(open == topos[i] || close == topos[i])
            quantidade++;
      }

      if(quantidade > maiorQuantidadeTopo)
      {
         maiorQuantidadeTopo = quantidade;
         melhorTopo = topos[i];
      }
   }

   // =========================================================
   // ENCONTRA O FUNDO MAIS TOCADO
   // =========================================================

   double melhorFundo = 0;
   int maiorQuantidadeFundo = 0;

   for(int i = 0; i < qtdFundos; i++)
   {
      int quantidade = 0;

      for(int j = 0; j < qtdCandles; j++)
      {
         double open  = iOpen(_Symbol, tf, j);
         double close = iClose(_Symbol, tf, j);

         if(open == fundos[i] || close == fundos[i])
            quantidade++;
      }

      if(quantidade > maiorQuantidadeFundo)
      {
         maiorQuantidadeFundo = quantidade;
         melhorFundo = fundos[i];
      }
   }

   // =========================================================
   // SE N > 0, VERIFICA QUANTOS CANDLES ESTÃO DENTRO
   // DAS DUAS BORDAS
   // =========================================================

   if(n > 0 && melhorTopo > 0 && melhorFundo > 0)
   {
      int candlesDentroDasBordas = 0;

      for(int i = 0; i < qtdCandles; i++)
      {
         double open  = iOpen(_Symbol, tf, i);
         double close = iClose(_Symbol, tf, i);

         bool openDentro =
            open >= melhorFundo &&
            open <= melhorTopo;

         bool closeDentro =
            close >= melhorFundo &&
            close <= melhorTopo;

         if(openDentro && closeDentro)
            candlesDentroDasBordas++;
      }

      // Se NÃO tiver mais de N candles dentro das bordas,
      // não desenha nenhuma das duas linhas.
      if(candlesDentroDasBordas <= n)
      {
         return;
      }
   }

   // =========================================================
   // REMOVE LINHAS ANTERIORES
   // =========================================================

   ObjectDelete(0, "BordaSuperior");
   ObjectDelete(0, "BordaInferior");

   // =========================================================
   // DESENHA TOPO MAIS TOCADO
   // =========================================================

   if(melhorTopo > 0 && melhorFundo > 0) {
      DesenharLinhaHorizontal("BordaSuperior",  melhorTopo,  clrBlue);
      DesenharLinhaHorizontal("BordaInferior",  melhorFundo,  clrBlue);
      config.bordas.min = melhorFundo;
      config.bordas.max = melhorTopo;
   }

   ChartRedraw();
}



double IsTrendSaturated(TimeframeConfig &config){
  double precoAtual = config.candles[0].close;
   // distância do preço para EMA50
   double distanceMA = MathAbs(precoAtual - ((config.movingAverage[0] + config.movingAverage[1] + config.movingAverage[2]) / 3));
   
   // candle atual muito grande
   double valAdx = 0, valTendency = 0, valAtrs = 0;
   
   if(config.adx[0] > 40)
      return 0;
      
   bool isConsolidatedMA = IsMA50Consolidated(config);
   if(isConsolidatedMA)
      return 0;
      
   return GetFactor(distanceMA, GetAverageValue(config.atr, 3),  ATR_MINIMUM);
}

bool IsMA50Consolidated(TimeframeConfig &config) {
   double slope = MathAbs(config.movingAverage[0] - config.movingAverage[10]);

   double maxMA = config.movingAverage[0];
   double minMA = config.movingAverage[0];

   for(int i = 0; i < 15; i++) {
      maxMA = MathMax(maxMA, config.movingAverage[i]);
      minMA = MathMin(minMA, config.movingAverage[i]);
   }

   double atr = GetAverageValue(config.atr, 3);
   return slope < atr * 0.2 && (maxMA - minMA) < atr * 0.5;
}

double GetFactor(double distanceMA, double atr, ATR_TYPE atrMinimum) {
   double minAtr = (double)atrMinimum / 10.0;
   double maxAtr = (double)ATR_5 / 10.0;

   // Percorre do maior para o menor
   double counter = 1;
   for(double i = maxAtr; i >= minAtr; i -= 1.0) {
      counter += 0.1;
      if(distanceMA > atr * i)   {
         if (i == minAtr) {
            return 1;
         } else {
            return ENABLE_TIMEFRAME_MULTIPLIER ? counter : 1;
         }
      }
   }

   return 0;
}

double GetAverageValue(double& indicator[], int qtdItems) {
   double val = 0;
   if (ArraySize(indicator) < qtdItems) {
      return 0;
   }
   
   for (int i = 0; i < qtdItems; i++) {
      val += indicator[i];
   }
   
   return val / qtdItems;
}
