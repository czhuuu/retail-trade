
**********************************************************************************
This file calculates retail trade measures following Blankespoor, deHaan, Wertz, and Zhu (2019).

Additional variables included in this code are for retail and non-retail trades: 
buys, sells, small/medium/large trades, and share-weighted average prices.

Small/medium/large cutoffs are based on shares and dollars.
Share-based: small trades are trade sizes < 500, medium trades are trade sizes between 500 and 10,000,
and large trades are trade sizes >=10,000.
Dollar-based: small trades are trades < $20,000, medium trades are trades between $20,000 and $50,000,
and large trades are trades >=$50,000.

Blankespoor, E., Dehaan, E., Wertz, J., and C. Zhu, 2019,
Why do individual investors disregard accounting information? 
The roles of information awareness and acquisition costs,
Journal of Accounting Research, 57(1), 53-84.

The code runs on WRDS and is updated for microsecond data. 
Uses Lee and Ready (2001) algorithm to classify trades as buys or sells, 
and uses the transaction price for retail trades on TRF.

Contact: Christina Zhu, chrzhu@wharton.upenn.edu
Last updated: 2/14/2017

**********************************************************************************
Based on code by Holden and Jacobsen (2014) to read the daily TAQ (DTAQ) data, create the official national best bid and offer (NBBO),
and compute standard liquidity measures.

Based on: Holden, C. and S. Jacobsen, 2014, Liquidity Measurement 
Problems in Fast, Competitive Markets: Expensive and Cheap Solutions,
Journal of Finance 69, 1747-1785.

**********************************************************************************
Example implementation:
    %pull(startyear=2003, endyear=2003, startmonth=9,endmonth=9,startdate=1,enddate=31);
    * You will need to run the code on your own WRDS folder and insert the path where you see '[YOUR WRDS TEMP FOLDER PATH HERE]' below.
    * See commented out lines at the very bottom of this file for another example implementation.
    * Please run just one month or a few months at a time.
    * Note: this code only works for pre-10/21/2016 TAQ data. Please see "Retail_trades_post201610.sas"
    for code to calculate variables for trades in post-10/21/2016 TAQ data.
**********************************************************************************;


/* Temp Library Name to save the final SAS dataset */
libname project '[YOUR WRDS TEMP FOLDER PATH HERE]'; 
options errors=50;
option msglevel=i mprint source; 

%put %sysfunc(getoption(work)); *checks work folder;

/*By default, the code runs for all TAQ firms. If you want certain firms only, 
put the symbols in below as shown and then uncomment out the three places indicated
below in the code (i.e. followed by the phrase "Uncomment out prior phrase if ...")*/

%let stocks='AAPL' 'IBM';

/*macro loop*/
%macro pull(startyear=,endyear=,startmonth=,endmonth=,startdate=,enddate=); 

/* Specify Name of the output SAS datasets */

%let prefixstartm=0;
%if &startmonth>=10 %then %let prefixstartm=;

%let prefixstartd=0;
%if &startdate>=10 %then %let prefixstartd=;

%let prefixendm=0;
%if &endmonth>=10 %then %let prefixendm=;

%let prefixendd=0;
%if &enddate>=10 %then %let prefixendd=;

%let TradesAll=trades_&startyear&prefixstartm&startmonth&prefixstartd&startdate._to_&endyear&prefixendm&endmonth&prefixendd&enddate;

/*Create empty output datasets to append to later*/

DATA project.&TradesAll;
 LENGTH SYM_ROOT $ 6 DATE 4 sumsize 8 sumtrades 8 buy_volume 8 buy_trades 8 sell_volume 8 sell_trades 8 small_volume 8 small_trades 8 med_volume 8 med_trades 8
	large_volume 8 large_trades 8 dollar_small_volume 8 dollar_small_trades 8 dollar_med_volume 8 dollar_med_trades 8 dollar_large_volume 8 dollar_large_trades 8 retail_trades 8
	retail_volume 8 retail_buy_volume 8 retail_buy_trades 8 retail_sell_volume 8 retail_sell_trades 8 retail_small_volume 8 retail_small_trades 8 retail_med_volume 8
	retail_med_trades 8 retail_large_volume 8 retail_large_trades 8 retail_dollar_small_volume 8 retail_dollar_small_trades 8 retail_dollar_med_volume 8 retail_dollar_med_trades 8
	retail_dollar_large_volume 8 retail_dollar_large_trades 8 BuyPrice_SW 8 SellPrice_SW 8 RetailBuyPrice_SW 8	RetailSellPrice_SW 8 NonRetailBuyPrice_SW 8 NonRetailSellPrice_SW 8
    nonretail_volume 8 nonretail_trades 8 nonretail_buy_volume 8 nonretail_buy_trades 8	nonretail_sell_volume 8	nonretail_sell_trades 8	nonretail_small_volume 8 nonretail_small_trades 8
	nonretail_med_volume 8 nonretail_med_trades 8 nonretail_large_volume 8 nonretail_large_trades 8	nonretail_dollar_small_volume 8 nonretail_dollar_small_trades 8	nonretail_dollar_med_volume 8
	nonretail_dollar_med_trades 8 nonretail_dollar_large_volume 8 nonretail_dollar_large_trades 8;
 FORMAT DATE DATE9.;
 INFORMAT DATE DATE9.;
 STOP;
RUN;

/*start macro loop*/
%do y=&startyear %to &endyear; /*cycling through years*/
	%do m=&startmonth %to &endmonth; /*cycling through months*/
		%let prefixm=0;
		%if &m>=10 %then %let prefixm=;

		%do d=&startdate %to &enddate; /*cycling through days*/
			%let prefixd=0;
			%if &d>=10 %then %let prefixd=;

			%if %sysfunc(exist(taqmsec.ctm_&y&prefixm&m&prefixd&d)) %then %do; /*checking to make sure it's a trading day*/

/* Select Period */
%let period= &y&prefixm&m&prefixd&d ;


/* STEP 1: RETRIEVE DAILY TRADE AND QUOTE (DTAQ) FILES FROM WRDS AND
           DOWNLOAD TO PC */

    data DailyNBBO;

    /* Retrieve NBBO data from files in YYYYMMDD format */

        set taqmsec.nbbom_&period;
		sym_root=cats(sym_root,sym_suffix); /*Some stocks have suffixes. Append prefix and suffix.*/
        /* Enter company tickers */
        where /* sym_root in (&stocks) and */  /*Uncomment out prior phrase if you only want certain stocks*/

        /* Quotes are retrieved prior to market open time to ensure NBBO 
		   Quotes are available for beginning of the day trades */
        (("9:00:00.000000"t) <= time_m <= ("16:00:00.000000"t));
        format date date9.;
        format time_m part_time trf_time TIME20.6;
    run;

   /* Retrieve Quote data from files in YYYYMMDD format */

    data DailyQuote;

        /* Enter DTAQ dates in YYYYMMDD format for Quote files */
        set taqmsec.cqm_&period;
		sym_root=cats(sym_root,sym_suffix);
        /* Enter company tickers */
        where /* sym_root in (&stocks) and */  /*Uncomment out prior phrase if you only want certain stocks*/

        /* Quotes are retrieved prior to market open time to ensure NBBO 
		   Quotes are available for beginning of the day trades*/
        (("9:00:00.000000"t) <= time_m <= ("16:00:00.000000"t));
        format date date9.;
        format time_m part_time trf_time TIME20.6;
    run;

    /* Retrieve Trade data from files in YYYYMMDD format */

    data DailyTrade;

        /* Enter DTAQ dates in YYYYMMDD format for Trade files */
        set taqmsec.ctm_&period;
		sym_root=cats(sym_root,sym_suffix);
        /* Enter same company tickers as above */
        where /* sym_root in (&stocks) and */   /*Uncomment out prior phrase if you only want certain stocks*/

        /* Retrieve trades during normal market hours */
        (("9:30:00.000000"t) <= time_m <= ("16:00:00.000000"t));
        type='T';
        format date date9.;
        format time_m part_time trf_time TIME20.6;
    run;

/* STEP 2: CLEAN THE DTAQ NBBO FILE */ 

data NBBO2;
    set DailyNBBO;

    /* Quote Condition must be normal (i.e., A,B,H,O,R,W) */
    if Qu_Cond not in ('A','B','H','O','R','W') then delete;

	/* If canceled then delete */
    if Qu_Cancel='B' then delete;

	/* if both ask and bid are set to 0 or . then delete */
    if Best_Ask le 0 and Best_Bid le 0 then delete;
    if Best_Asksiz le 0 and Best_Bidsiz le 0 then delete;
    if Best_Ask = . and Best_Bid = . then delete;
    if Best_Asksiz = . and Best_Bidsiz = . then delete;

	/* Create spread and midpoint */
    Spread=Best_Ask-Best_Bid;
    Midpoint=(Best_Ask+Best_Bid)/2;

	/* If size/price = 0 or . then price/size is set to . */
    if Best_Ask le 0 then do;
        Best_Ask=.;
        Best_Asksiz=.;
    end;
    if Best_Ask=. then Best_Asksiz=.;
    if Best_Asksiz le 0 then do;
        Best_Ask=.;
        Best_Asksiz=.;
    end;
    if Best_Asksiz=. then Best_Ask=.;
    if Best_Bid le 0 then do;
        Best_Bid=.;
        Best_Bidsiz=.;
    end;
    if Best_Bid=. then Best_Bidsiz=.;
    if Best_Bidsiz le 0 then do;
        Best_Bid=.;
        Best_Bidsiz=.;
    end;
    if Best_Bidsiz=. then Best_Bid=.;

	/*	Bid/Ask size are in round lots, replace with new shares variable*/
	Best_BidSizeShares = Best_BidSiz * 100;
	Best_AskSizeShares = Best_AskSiz * 100;
run;

/* STEP 3: GET PREVIOUS MIDPOINT */

proc sort 
    data=NBBO2 (drop = Best_BidSiz Best_AskSiz);
    by sym_root date;
run; 

data NBBO2;
    set NBBO2;
    by sym_root date;
    lmid=lag(Midpoint);
    if first.sym_root or first.date then lmid=.;
    lm25=lmid-2.5;
    lp25=lmid+2.5;
run;

/* If the quoted spread is greater than $5.00 and the bid (ask) price is less
   (greater) than the previous midpoint - $2.50 (previous midpoint + $2.50), 
   then the bid (ask) is not considered. */

data NBBO2;
    set NBBO2;
    if Spread gt 5 and Best_Bid lt lm25 then do;
        Best_Bid=.;
        Best_BidSizeShares=.;
    end;
    if Spread gt 5 and Best_Ask gt lp25 then do;
        Best_Ask=.;
        Best_AskSizeShares=.;
    end;
	keep date time_m sym_root Best_Bidex Best_Bid Best_BidSizeShares Best_Askex 
         Best_Ask Best_AskSizeShares Qu_SeqNum;
run;

/* STEP 4: OUTPUT NEW NBBO RECORDS - IDENTIFY CHANGES IN NBBO RECORDS 
   (CHANGES IN PRICE AND/OR DEPTH) */

data NBBO2;
    set NBBO2;
    if sym_root ne lag(sym_root) 
       or date ne lag(date) 
       or Best_Ask ne lag(Best_Ask) 
       or Best_Bid ne lag(Best_Bid) 
       or Best_AskSizeShares ne lag(Best_AskSizeShares) 
       or Best_BidSizeShares ne lag(Best_BidSizeShares); 
run;

/* STEP 5: CLEAN DTAQ QUOTES DATA */

data quoteAB;
    set DailyQuote;

    /* Create spread and midpoint*/;
    Spread=Ask-Bid;

	/* Delete if abnormal quote conditions */
    if Qu_Cond not in ('A','B','H','O','R','W') then delete; 

	/* Delete if abnormal crossed markets */
    if Bid>Ask then delete;

	/* Delete abnormal spreads*/
    if Spread>5 then delete;

	/* Delete withdrawn Quotes. This is 
	   when an exchange temporarily has no quote, as indicated by quotes 
	   with price or depth fields containing values less than or equal to 0 
	   or equal to '.'. See discussion in Holden and Jacobsen (2014), 
	   page 11. */
    if Ask le 0 or Ask =. then delete;
    if Asksiz le 0 or Asksiz =. then delete;
    if Bid le 0 or Bid =. then delete;
    if Bidsiz le 0 or Bidsiz =. then delete;
	drop Sym_Suffix Bidex Askex Qu_Cancel Qu_Source RPI SSR LULD_BBO_CQS 
         LULD_BBO_UTP FINRA_ADF_MPID SIP_Message_ID Part_Time RRN TRF_Time 
         Spread NATL_BBO_LULD;
run;

/* STEP 6: CLEAN DAILY TRADES DATA - DELETE ABNORMAL TRADES */

data trade2;
    set DailyTrade;
    where Tr_Corr eq '00' and price gt 0;
	drop Tr_Corr Tr_Source TR_RF Part_Time RRN TRF_Time Sym_Suffix Tr_SCond 
         Tr_StopInd;
run;

/* STEP 7: THE NBBO FILE IS INCOMPLETE BY ITSELF (IF A SINGLE EXCHANGE 
   HAS THE BEST BID AND OFFER, THE QUOTE IS INCLUDED IN THE QUOTES FILE, BUT 
   NOT THE NBBO FILE). TO CREATE THE COMPLETE OFFICIAL NBBO, WE NEED TO 
   MERGE WITH THE QUOTES FILE (SEE FOOTNOTE 6 AND 24 IN HOLDEN AND JACOBSEN 2014) */

data quoteAB2 (rename=(Ask=Best_Ask Bid=Best_Bid));
    set quoteAB;
    where NatBBO_Ind='1' or NASDBBO_Ind='4';
    keep date time_m sym_root Qu_SeqNum Bid Best_BidSizeShares Ask Best_AskSizeShares;

	/*	Bid/Ask size are in round lots, replace with new shares variable
	and rename Best_BidSizeShares and Best_AskSizeShares*/
	Best_BidSizeShares = Bidsiz * 100;
	Best_AskSizeShares = Asksiz * 100;
run;

proc sort data=NBBO2;
    by sym_root date Qu_SeqNum;
run;

proc sort data=quoteAB2;
    by sym_root date Qu_SeqNum;
run;

data OfficialCompleteNBBO (drop=Best_Askex Best_Bidex);
    set NBBO2 quoteAB2;
    by sym_root date Qu_SeqNum;
run;

/* If the NBBO Contains two quotes in the exact same microseond, assume 
   last quotes (based on sequence number) is active one */
proc sort data=OfficialCompleteNBBO;
    by sym_root date time_m descending Qu_SeqNum;
run;

proc sort data=OfficialCompleteNBBO nodupkey;
    by sym_root date time_m;
run;

/* STEP 8: INTERLEAVE TRADES WITH NBBO QUOTES. DTAQ TRADES AT MICROSECOND 
   TMMMMMM ARE MATCHED WITH THE DTAQ NBBO QUOTES STILL IN FORCE AT THE 
   MICROSECOND TMMMMM(M-1) */;

data OfficialCompleteNBBO;
    set OfficialCompleteNBBO;type='Q';
    time_m=time_m+.000001;
	drop Qu_SeqNum;
run;

proc sort data=OfficialCompleteNBBO;
    by sym_root date time_m;
run;

proc sort data=trade2;
    by sym_root date time_m Tr_SeqNum;
run;

data TradesPriorNBBOandQuotes;
    set OfficialCompleteNBBO trade2;
    by sym_root date time_m type;
run;

data TradesPriorNBBOandQuotes (drop=Best_Ask Best_Bid Best_AskSizeShares
    Best_BidSizeShares);
    set TradesPriorNBBOandQuotes;
    by sym_root date;
    retain QTime NBO NBB NBOqty NBBqty;
    if first.sym_root or first.date and type='T' then do;
		QTime=.;
        NBO=.;
        NBB=.;
        NBOqty=.;
        NBBqty=.;
    end;
    if type='Q' then Qtime=time_m;
        else Qtime=Qtime;
    if type='Q' then NBO=Best_Ask;
        else NBO=NBO;
    if type='Q' then NBB=Best_Bid;
        else NBB=NBB;
    if type='Q' then NBOqty=Best_AskSizeShares;
        else NBOqty=NBOqty;
    if type='Q' then NBBqty=Best_BidSizeShares;
        else NBBqty=NBBqty;
	format Qtime TIME20.6;
run;

/* STEP 9: CLASSIFY TRADES AS "BUYS" OR "SELLS" USING:
   LR = LEE AND READY (1991); DETERMINE NBBO 
   MIDPOINT AND LOCKED AND CROSSED NBBOs */

data BuySellIndicators;
    set TradesPriorNBBOandQuotes;
    where type='T';
    midpoint=(NBO+NBB)/2;
    if NBO=NBB then lock=1;else lock=0;
    if NBO<NBB then cross=1;else cross=0;
run;

/* Determine Whether Trade Price is Higher or Lower than Previous Trade 
   Price, or "Trade Direction" */
data BuySellIndicators;
    set BuySellIndicators;
    by sym_root date;
	retain direction2;
    direction=dif(price);
    if first.sym_root or first.date then direction=.;
    if direction ne 0 then direction2=direction; 
    else direction2=direction2;
	drop direction;
run;

/* First Classification Step: Classify Trades Using Tick Test */
data BuySellIndicators;
    set BuySellIndicators;
    if direction2>0 then BuySellLR=1;
    if direction2<0 then BuySellLR=-1;
    if direction2=. then BuySellLR=.;
run;

/* Second Classification Step: Update Trade Classification When 
   Conditions are Met as Specified by LR */
data BuySellIndicators;
    set BuySellIndicators;
    if lock=0 and cross=0 and price gt midpoint then BuySellLR=1;
    if lock=0 and cross=0 and price lt midpoint then BuySellLR=-1;
run;

/* STEP 10: CALCULATE TRADE SIZES */

data BuySellIndicators;
	set BuySellIndicators;
	dollar_tradesize=SIZE*PRICE;
	/* Classify based on number of shares */
	small_trade=0;
	if SIZE<=499 then small_trade=1;
	med_trade=0;
	if (SIZE>=500 and SIZE<=9999) then med_trade=1;
	large_trade=0;
	if SIZE>=10000 then large_trade=1;
	/* Classify based on dollar size */
	dollar_small_trade=0;
	if dollar_tradesize<20000 then dollar_small_trade=1;
	dollar_med_trade=0;
	if (dollar_tradesize>=20000 and dollar_tradesize<50000) then dollar_med_trade=1;
	dollar_large_trade=0;
	if dollar_tradesize>=50000 then dollar_large_trade=1;
	/* Delete Trades Associated with Locked or Crossed Best Bids or Best 
   Offers */
	if lock=1 or cross=1 then delete;
run;

/* STEP 11: INDICATOR FOR MARKET RETAIL ORDERS */

data BuySellIndicators;
	set BuySellIndicators;
	frac_penny=100*mod(PRICE,0.01);
	retail=0;
	if (EX='D' and ((frac_penny>0 and frac_penny<0.4) or (frac_penny>0.6 and frac_penny<1))) then retail=1;
	if (EX='D' and frac_penny>0 and frac_penny<0.4) then BuySellLR=-1;
	if (EX='D' and frac_penny>0.6 and frac_penny<1) then BuySellLR=1;
	buy_indicator=0;
	if BuySellLR=1 then buy_indicator=1;
	sell_indicator=0;
	if BuySellLR=-1 then sell_indicator=1;
	wBuyPrice_SW=PRICE*buy_indicator*SIZE;
	wSellPrice_SW=PRICE*sell_indicator*SIZE;
	wRetailBuyPrice_SW=PRICE*retail*buy_indicator*SIZE;
	wRetailSellPrice_SW=PRICE*retail*sell_indicator*SIZE;
run;

/* STEP 12: AGGREGATE BY FIRM-DAY */


/* Find average across firm-day */
proc sql;
    create table TradeSizesBuySell 
    as select sym_root,date,
    sum(size) as sumsize,
	count(PRICE) as sumtrades,
    sum(SIZE*buy_indicator) as buy_volume,
	sum(buy_indicator) as buy_trades,
	sum(SIZE*sell_indicator) as sell_volume,
	sum(sell_indicator) as sell_trades,
	sum(SIZE*small_trade) as small_volume,
	sum(small_trade) as small_trades,
	sum(SIZE*med_trade) as med_volume,
	sum(med_trade) as med_trades,
	sum(SIZE*large_trade) as large_volume,
	sum(large_trade) as large_trades,
	sum(SIZE*dollar_small_trade) as dollar_small_volume,
	sum(dollar_small_trade) as dollar_small_trades,
	sum(SIZE*dollar_med_trade) as dollar_med_volume,
	sum(dollar_med_trade) as dollar_med_trades,
	sum(SIZE*dollar_large_trade) as dollar_large_volume,
	sum(dollar_large_trade) as dollar_large_trades,
	sum(retail) as retail_trades,
	sum(SIZE*retail) as retail_volume,
	sum(SIZE*buy_indicator*retail) as retail_buy_volume,
	sum(buy_indicator*retail) as retail_buy_trades,
	sum(SIZE*sell_indicator*retail) as retail_sell_volume,
	sum(sell_indicator*retail) as retail_sell_trades,
	sum(SIZE*small_trade**retail) as retail_small_volume,
	sum(small_trade*retail) as retail_small_trades,
	sum(SIZE*med_trade*retail) as retail_med_volume,
	sum(med_trade*retail) as retail_med_trades,
	sum(SIZE*large_trade*retail) as retail_large_volume,
	sum(large_trade*retail) as retail_large_trades,
	sum(SIZE*dollar_small_trade*retail) as retail_dollar_small_volume,
	sum(dollar_small_trade*retail) as retail_dollar_small_trades,
	sum(SIZE*dollar_med_trade*retail) as retail_dollar_med_volume,
	sum(dollar_med_trade*retail) as retail_dollar_med_trades,
	sum(SIZE*dollar_large_trade*retail) as retail_dollar_large_volume,
	sum(dollar_large_trade*retail) as retail_dollar_large_trades,
    sum(wBuyPrice_SW) as waBuyPrice_SW,
    sum(wSellPrice_SW) as waSellPrice_SW,
	sum(wRetailBuyPrice_SW) as waRetailBuyPrice_SW,
	sum(wRetailSellPrice_SW) as waRetailSellPrice_SW
    from BuySellIndicators
    group by sym_root,date 
    order by sym_root,date;
quit;

* calculate non-retail trades as total trades minus retail ones;

/* Calculate Share-Weighted (SW) Buy and Sell Prices */
data TradeSizesBuySell;
    set TradeSizesBuySell;
    BuyPrice_SW=waBuyPrice_SW/buy_volume;
    SellPrice_SW=waSellPrice_SW/sell_volume;
	RetailBuyPrice_SW=waRetailBuyPrice_SW/retail_buy_volume;
	RetailSellPrice_SW=waRetailSellPrice_SW/retail_sell_volume;
	NonRetailBuyPrice_SW=(waBuyPrice_SW-waRetailBuyPrice_SW)/(buy_volume-retail_buy_volume);
	NonRetailSellPrice_SW=(waSellPrice_SW-waRetailSellPrice_SW)/(sell_volume-retail_sell_volume);
    nonretail_volume=sumsize-retail_volume;
	nonretail_trades=sumtrades-retail_trades;
    nonretail_buy_volume=buy_volume-retail_buy_volume;
	nonretail_buy_trades=buy_trades-retail_buy_trades;
	nonretail_sell_volume=sell_volume-retail_sell_volume;
	nonretail_sell_trades=sell_trades-retail_sell_trades;
	nonretail_small_volume=small_volume-retail_small_volume;
	nonretail_small_trades=small_trades-retail_small_trades;
	nonretail_med_volume=med_volume-retail_med_volume;
	nonretail_med_trades=med_trades-retail_med_trades;
	nonretail_large_volume=large_volume-retail_large_volume;
	nonretail_large_trades=large_trades-retail_large_trades;
	nonretail_dollar_small_volume=dollar_small_volume-retail_dollar_small_volume;
	nonretail_dollar_small_trades=dollar_small_trades-retail_dollar_small_trades;
	nonretail_dollar_med_volume=dollar_med_volume-retail_dollar_med_volume;
	nonretail_dollar_med_trades=dollar_med_trades-retail_dollar_med_trades;
	nonretail_dollar_large_volume=dollar_large_volume-retail_dollar_large_volume;
	nonretail_dollar_large_trades=dollar_large_trades-retail_dollar_large_trades;
	drop waBuyPrice_SW waSellPrice_SW waRetailBuyPrice_SW waRetailSellPrice_SW;
run;

proc append base=project.&TradesAll data=TradeSizesBuySell force;run;


			%end;
		%end;
	%end;
%end;
%MEND pull;

/*This is where you actually specify the years, months, days and then run the macro. The dates have to be consecutive and the startmonth
has to be before endmonth, startdate before enddate, too.*/

/*
%pull(startyear=2003, endyear=2003, startmonth=9,endmonth=9,startdate=1,enddate=31);

%pull(startyear=2016, endyear=2016, startmonth=10,endmonth=10,startdate=1,enddate=20);*/
