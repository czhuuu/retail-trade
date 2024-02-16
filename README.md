# retail-trade

The "Retail_trades_pre201610" and "Retail_trades_post201610" files each contain a SAS macro, meant to run on WRDS, to calculate retail trade measures following Boehmer, Jones, Zhang, and Zhang (2021).

Retail trading volume is implemented in <a href="https://onlinelibrary.wiley.com/doi/abs/10.1111/1475-679X.12248"> Blankespoor, deHaan, Wertz, and Zhu (2019)</a>. If you use this code, please cite: Blankespoor, E., Dehaan, E., Wertz, J., & Zhu, C. (2019). Why do individual investors disregard accounting information? The roles of information awareness and acquisition costs. _Journal of Accounting Research, 57_(1), 53-84.

The "pre201610" file is for TAQ data 10/20/2016 and earlier, and the "post201610" file is for TAQ data 10/21/2016 and later.

The two files contain code to calculate several additional measures not used in the paper (e.g., trade size-based measures) as well. Please read the files carefully for further instructions and assumptions made.

Note: if you would like to use the Lee-Ready algorithm (Lee and Ready 1991) to sign the retail trades, as suggested by Barber, Huang, Jorion, Odean, and Schwarz (2024), then you can simply comment out the lines of code that replace BuySellLR with the alternative buy/sell indicator based on the fraction of a cent price improvement test. This would be lines 456-457 of Retail_trades_pre201610.sas and lines 455-456 of Retail_trades_post201610.sas.
