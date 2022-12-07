# This query give the market value of each of the holdings in each portfolio on each day from OCT 1 to OCT 31
SELECT sip.PORT_ID,prt.TRADE_DATE,prt.SEC_ID,prt.CLOSE_PRICE*sip.NUM_SHARES AS HOLDING_VALUE
FROM PRICE_TABLE prt
INNER JOIN SEC_IN_PORT sip ON sip.SEC_ID=prt.SEC_ID AND sip.TRADE_DATE=prt.TRADE_DATE
ORDER BY 1,3,2;

#This query shows the market value of each portfolio on each day
#Simply, this query displays portfolio level rather than security level (which is what is displayed in the above query)
SELECT t.PORT_ID,t.PORT_LONG_NAME,t.TRADE_DATE, SUM(t.HOLDING_VALUE) AS Market_Value FROM (
SELECT sip.PORT_ID, pt.PORT_LONG_NAME,
prt.TRADE_DATE, prt.SEC_ID, prt.CLOSE_PRICE * sip.NUM_SHARES AS HOLDING_VALUE
FROM PRICE_TABLE prt
INNER JOIN SEC_IN_PORT sip ON sip.SEC_ID=prt.SEC_ID AND sip.TRADE_DATE = prt.TRADE_DATE
INNER JOIN PORT_TABLE pt ON pt.PORT_ID=sip.PORT_ID)
AS t
GROUP BY t.PORT_ID, t.TRADE_DATE
ORDER BY t.PORT_ID,t.TRADE_DATE;

#Created view for portfolio-level query above
CREATE VIEW PORT_VALUES AS
(SELECT t.PORT_ID,t.PORT_LONG_NAME,t.TRADE_DATE, SUM(t.HOLDING_VALUE) AS Market_Value FROM (
SELECT sip.PORT_ID, pt.PORT_LONG_NAME,
prt.TRADE_DATE, prt.SEC_ID, prt.CLOSE_PRICE * sip.NUM_SHARES AS HOLDING_VALUE
FROM PRICE_TABLE prt
INNER JOIN SEC_IN_PORT sip ON sip.SEC_ID=prt.SEC_ID AND sip.TRADE_DATE = prt.TRADE_DATE
INNER JOIN PORT_TABLE pt ON pt.PORT_ID=sip.PORT_ID)
AS t
GROUP BY t.PORT_ID, t.TRADE_DATE
ORDER BY t.PORT_ID,t.TRADE_DATE);

#Verify that PORT_VALUES view worked
SELECT * FROM PORT_VALUES;

#Setting up table in order for final table to run calculations based on beginning start date and end start date
CREATE VIEW PORT_START_END AS
    SELECT PORT_ID, PORT_LONG_NAME, MIN(TRADE_DATE) AS START_MONTH, MAX(TRADE_DATE) AS END_MONTH
        FROM PORT_VALUES GROUP BY PORT_ID, PORT_LONG_NAME;

#Verify that PORT_START_END view worked
SELECT * FROM PORT_START_END;

#This query returns the 1 month returns for each portfolio ranked and ordered from biggest winners to biggest losers
SELECT RANK() OVER(ORDER BY M1_RETURN DESC) "Rank", port_open.PORT_ID, port_open.PORT_LONG_NAME,
	port_open.MONTH_START, port_close.MONTH_END,port_open.MONTH_OPEN, port_close.MONTH_CLOSE,
    (port_close.MONTH_CLOSE/port_open.MONTH_OPEN-1)*100 AS M1_RETURN
FROM
    (SELECT pv.PORT_ID, pv.PORT_LONG_NAME, pv.TRADE_DATE as MONTH_START, pv.Market_Value AS MONTH_OPEN 
    FROM PORT_VALUES AS pv INNER JOIN PORT_START_END as ps1
	ON pv.PORT_ID = ps1.PORT_ID AND pv.TRADE_DATE = ps1.START_MONTH) AS port_open
INNER JOIN 
    (SELECT pv.PORT_ID, pv.PORT_LONG_NAME, pv.TRADE_DATE as MONTH_END, pv.Market_Value AS MONTH_CLOSE
    FROM PORT_VALUES AS pv INNER JOIN PORT_START_END as ps1
	ON pv.PORT_ID = ps1.PORT_ID AND pv.TRADE_DATE = ps1.END_MONTH) AS port_close
ON port_open.PORT_ID = port_close.PORT_ID
ORDER BY M1_RETURN DESC;

#Created view for winners-losers rankings above
CREATE VIEW WINNERS_LOSERS AS
(SELECT RANK() OVER(ORDER BY M1_RETURN DESC) "Rank", port_open.PORT_ID, port_open.PORT_LONG_NAME,
	port_open.MONTH_START, port_close.MONTH_END,CONCAT('$', FORMAT(port_open.MONTH_OPEN, 2)) MONTH_OPEN,
   CONCAT('$', FORMAT(port_close.MONTH_CLOSE, 2)) MONTH_CLOSE,
   (port_close.MONTH_CLOSE/port_open.MONTH_OPEN-1)*100 AS M1_RETURN
FROM
    (SELECT pv.PORT_ID, pv.PORT_LONG_NAME, pv.TRADE_DATE as MONTH_START, pv.Market_Value AS MONTH_OPEN 
    FROM PORT_VALUES AS pv INNER JOIN PORT_START_END as ps1
        ON pv.PORT_ID = ps1.PORT_ID AND pv.TRADE_DATE = ps1.START_MONTH) AS port_open
INNER JOIN 
    (SELECT pv.PORT_ID, pv.PORT_LONG_NAME, pv.TRADE_DATE as MONTH_END, pv.Market_Value AS MONTH_CLOSE
    FROM PORT_VALUES AS pv INNER JOIN PORT_START_END as ps1
        ON pv.PORT_ID = ps1.PORT_ID AND pv.TRADE_DATE = ps1.END_MONTH) AS port_close
ON port_open.PORT_ID = port_close.PORT_ID
ORDER BY M1_RETURN DESC);

#Verify that WINNERS_LOSERS view worked
SELECT * FROM WINNERS_LOSERS;

####--Winners-losers by strategy
SELECT RANK() OVER(ORDER BY wl.M1_RETURN DESC) "Rank", st.STRATEGY_LONG_NAME, wl.M1_RETURN
FROM STRAT_TABLE st
INNER JOIN PORT_TABLE pt ON pt.STRAT_ID=st.STRAT_ID
INNER JOIN WINNERS_LOSERS wl ON wl.PORT_ID=pt.PORT_ID
ORDER BY wl.M1_RETURN DESC;

##Winners-losers by long/short
SELECT RANK() OVER(ORDER BY M1_RETURN DESC) "Rank", pt.PORT_LONG_NAME, pt.LONG_SHORT, M1_RETURN
FROM WINNERS_LOSERS wl
INNER JOIN PORT_TABLE pt ON pt.PORT_ID=wl.PORT_ID;

##Returns long only ports where BEG MV greater than $100m
SELECT LONG_SHORT, CONCAT('$', FORMAT(START_MV, 2)) "Beginning MV"
FROM PORT_TABLE
WHERE LONG_SHORT='Long Only'
GROUP BY START_MV,LONG_SHORT
HAVING START_MV>100000000;

##Newest to Oldest client
SELECT CLIENT_LONG_NAME,ONBOARDING_DATE,TERMINATION_DATE,
CONCAT((DATEDIFF(CURRENT_DATE,ONBOARDING_DATE))/365," years") AS Duration
FROM CLIENT_TABLE
WHERE TERMINATION_DATE IS NULL
ORDER BY 2 DESC;

##SHOW PM Name
SELECT CONCAT(FIRST_NAME,' ',LAST_NAME) "Portfolio Manager Name"
FROM PM_TABLE;

##Indexes
CREATE INDEX CLIENT_TABLE_INDEX
ON CLIENT_TABLE (CLIENT_ID);

CREATE INDEX PORT_TABLE_INDEX
ON PORT_TABLE (PORT_ID);

##MODIFICATIONS#########################
##ETFs and common shares update description
SELECT * FROM STRAT_TABLE;

UPDATE STRAT_TABLE
SET descriptions='ETFs and common shares of companies in the United States market.'
WHERE STRAT_ID=601;

UPDATE STRAT_TABLE
SET descriptions='ETFs and common shares of companies in the Canadian market.'
WHERE STRAT_ID=603;

SELECT * FROM STRAT_TABLE;

##Insert fixed income strategies
INSERT INTO STRAT_TABLE VALUES
(606,'Cash Management',0.1,'Cash securities of durration no longer than 90 days.'),
(607,'Mortgage-Backed Security',0.7,'Fixed income instruments backed by mortgages.');

SELECT * FROM STRAT_TABLE;

##Delete unused fixed income strategies
DELETE FROM STRAT_TABLE
WHERE STRAT_ID IN (606,607);

SELECT * FROM STRAT_TABLE;

##Alter name to text value from varchar in security table
ALTER TABLE SEC_INFO
MODIFY SECURITY_LONG_NAME VARCHAR(100);

SELECT * FROM SEC_INFO;