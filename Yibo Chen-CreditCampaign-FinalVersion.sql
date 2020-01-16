SELECT * FROM base LIMIT 20;
SELECT * FROM call_record LIMIT 20;
SELECT * FROM change_record LIMIT 20;
SELECT * FROM decision LIMIT 20;
SELECT * FROM letter LIMIT 20;

-- 1. response rate by date
SELECT call_date, COUNT(distinct acct_num) AS number_calls FROM call_record GROUP BY call_date;

-- 2. Overall approval rate and decline rate
SELECT C.status, C.number, C.number / A.total_population AS rate
FROM (SELECT D.decision_status AS status, COUNT(DISTINCT D.acct_decision_id) AS number FROM decision AS D GROUP BY 1) AS C
LEFT JOIN (SELECT COUNT(acct_decision_id) AS total_population FROM decision) AS A ON C.status=C.status; 

/*Another method:*/
select 
sum(case when decision_status = 'AP' then 1 else 0 end) / count(acct_decision_id) as approval_rate,
sum(case when decision_status = 'DL' then 1 else 0 end) / count(acct_decision_id) as decline_rate
from decision;

-- 3. for approved accounts, check whether their credit limit has been changed correctly based on the offer_amount
SELECT A.* FROM ( 
SELECT B.*, (B.credit_limit+B.offer_amount) AS should_up_to, CR.credit_limit_after AS set_limit
FROM base AS B 
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN change_record AS CR ON D.acct_decision_id=CR.account_number
WHERE D.decision_status="AP") AS A
WHERE A.should_up_to!=A.set_limit;

/*Another method:*/
SELECT A.* FROM
(select base.acct_num, 
base.credit_limit,base.offer_amount, 
d.decision_status,
c.credit_limit_after,
base.credit_limit+base.offer_amount-credit_limit_after as mismatch
from base 
left join decision d on base.acct_num=d.acct_decision_id
left join change_record as c on base.acct_num=c.account_number
where decision_status='AP') A
WHERE A.MISMATCH <> 0;

-- 4.1 letter monitoring for sending check
SELECT D.acct_decision_id 
FROM decision AS D
LEFT JOIN letter AS L ON D.acct_decision_id=L.account_number
WHERE SUBSTRING(L.Letter_trigger_date,1,7)<SUBSTRING(D.decision_date,1,7);

SELECT A.* FROM
(SELECT B.acct_num, D.decision_status, L.letter_code, SUBSTRING(D.decision_date,1,7) AS des, SUBSTRING(L.Letter_trigger_date,1,7) AS trig
FROM base AS B
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number
WHERE  D.decision_status IS NOT NULL) AS A 
WHERE A.des<=A.trig or A.trig IS NULL;

-- 4.2 letter monitoring for code
SELECT A.* FROM
(SELECT B.acct_num, D.decision_status, D.decision_date, L.Letter_trigger_date, L.letter_code, L.language,
CASE WHEN (L.language='French' AND (L.letter_code='AE001' OR L.letter_code='RE001')) THEN 'Wrong'
	 WHEN (L.language='English' AND (L.letter_code='AE002' OR L.letter_code='RE002')) THEN 'Wrong'
     ELSE 'Correct' END AS check_language
FROM base AS B
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number
WHERE  D.decision_status IS NOT NULL) AS A 
WHERE check_language='Wrong';

-- 5. final monitoring
SELECT B.*, D.decision_status, D.decision_date, L.Letter_trigger_date, L.letter_code, L.language, CR.credit_limit_after, 
CASE WHEN D.decision_status="AP" AND (B.credit_limit+B.offer_amount-CR.credit_limit_after)!=0 
		  THEN "1" ELSE "0" END AS mismatch_flag,
CASE WHEN D.decision_status IS NOT NULL AND L.Letter_trigger_date IS NOT NULL AND DATEDIFF(D.decision_date,L.Letter_trigger_date)<=0 
		  THEN "0" ELSE "1" END AS missing_letter_flag,
CASE WHEN (L.language='French' AND (L.letter_code='AE001' OR L.letter_code='RE001')) THEN '1'
	 WHEN (L.language='English' AND (L.letter_code='AE002' OR L.letter_code='RE002')) THEN '1'
     ELSE '0' END AS wrong_letter_flag
FROM base AS B
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number
LEFT JOIN change_record AS CR ON B.acct_num=CR.account_number;




