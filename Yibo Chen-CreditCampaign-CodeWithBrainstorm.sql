SELECT * FROM base LIMIT 20;
SELECT * FROM call_record LIMIT 20;
SELECT * FROM change_record LIMIT 20;
SELECT * FROM decision LIMIT 20;
SELECT * FROM letter LIMIT 20;

-- 1.
SELECT call_date, COUNT(acct_num) AS number_calls FROM call_record GROUP BY call_date;
/*【看题看题看题！！！！】上边是：Check how many calls in and respond every day*/
/*然而原题是：Check how many 「people」 call in and respond every day*/
/*订：*/
SELECT call_date, COUNT(distinct acct_num) AS number_calls FROM call_record GROUP BY call_date;

-- 2.
/*试一下能不能出来？？？？？？第二个COUNT(distinct B.acct_num)会不会被算在GROUP BY里边？？？？？？？*/
/* 【Result 1】能run出来，但是意料之中的错误了😂因为【第二个COUNT(distinct B.acct_num)会·会·会被算在GROUP BY里边】！！！！*/
SELECT D.decision_status, COUNT(DISTINCT D.acct_decision_id) AS number, COUNT(DISTINCT D.acct_decision_id) / COUNT(distinct B.acct_num) AS rate
FROM base AS B LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id GROUP BY 1;

/*【Result 2】那就用derived table！*/
/*但是还是错的：contains nonaggregated column 'A.total_population' which is not functionally dependent on columns in GROUP BY claus*/
SELECT D.decision_status, COUNT(DISTINCT D.acct_decision_id) AS number, COUNT(DISTINCT D.acct_decision_id) / A.total_population AS rate
FROM base AS B 
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id 
LEFT JOIN (SELECT acct_num AS acc, COUNT(acct_num) AS total_population FROM base GROUP BY 1) AS A ON B.acct_num=A.acc
GROUP BY 1;

/*...能出来了！但是是错的😂*//*好吧，原因在于并不是所有base中的人，都在decision里边啦！！！！！！*/
SELECT C.status, C.number, C.number / A.total_population AS rate
FROM (SELECT D.decision_status AS status, COUNT(DISTINCT D.acct_decision_id) AS number FROM decision AS D GROUP BY 1) AS C
LEFT JOIN (SELECT COUNT(acct_num) AS total_population FROM base) AS A ON C.status=C.status; 

SELECT COUNT(acct_num) AS total_population FROM base;/*【tip】当只有一个aggregation function在SELECT的时候，可以不用GROUP BY~*/

/*👌👌*/
SELECT C.status, C.number, C.number / A.total_population AS rate
FROM (SELECT D.decision_status AS status, COUNT(DISTINCT D.acct_decision_id) AS number FROM decision AS D GROUP BY 1) AS C
LEFT JOIN (SELECT COUNT(acct_decision_id) AS total_population FROM decision) AS A ON C.status=C.status; 

/*老师的Overall approval rate and decline rate：*/
select 
sum(case when decision_status = 'AP' then 1 else 0 end) / count(acct_decision_id) as approval_rate,
sum(case when decision_status = 'DL' then 1 else 0 end) / count(acct_decision_id) as decline_rate
from decision;

-- 3.
/*？？？？？？？？？？？？看一下能不能run？？？？？？？？？？？？*/
/*【能】run了*/
SELECT B.*, (B.credit_limit+B.offer_amount) AS up_to, CR.credit_limit_after
FROM base AS B 
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN change_record AS CR ON D.acct_decision_id=CR.account_number
WHERE D.decision_status="AP" AND
(B.credit_limit+B.offer_amount)!=CR.credit_limit_after;
/*但是上边这个好像，用derived table意义不大啊😂*/

/*??????????试一下，答案一样不？？？？？？？？？？？*/
/*【能】run出来，而且是对的👌*/
SELECT A.* FROM ( 
SELECT B.*, (B.credit_limit+B.offer_amount) AS should_up_to, CR.credit_limit_after
FROM base AS B 
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN change_record AS CR ON D.acct_decision_id=CR.account_number
WHERE D.decision_status="AP" AND (B.credit_limit+B.offer_amount)!=CR.credit_limit_after) AS A;
/*但是这个版本，用derived table意义也不大啊😂*/

/*👌*/
SELECT A.* FROM ( 
SELECT B.*, (B.credit_limit+B.offer_amount) AS should_up_to, CR.credit_limit_after AS set_limit
FROM base AS B 
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN change_record AS CR ON D.acct_decision_id=CR.account_number
WHERE D.decision_status="AP") AS A
WHERE A.should_up_to!=A.set_limit;

/*老师的:*/
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

-- 4.1
SELECT D.acct_decision_id 
FROM decision AS D
LEFT JOIN letter AS L ON D.acct_decision_id=L.account_number
WHERE SUBSTRING(L.Letter_trigger_date,1,7)<SUBSTRING(D.decision_date,1,7);

/*然而这里老师还是考虑了base.........还是要【考虑base中是否有人既没有被AP也没有被DL】，方法就是LEFT JOIN base,那样的话就会可能有null出现在trig date！！*/
SELECT A.* FROM
(SELECT B.acct_num, D.decision_status, L.letter_code, SUBSTRING(D.decision_date,1,7) AS des, SUBSTRING(L.Letter_trigger_date,1,7) AS trig
FROM base AS B
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number) AS A 
WHERE A.des<=A.trig or A.trig IS NULL;

/*⬆️上边还不够严谨⬆️*/
/*⬇️👌⬇️ 如果这里按照题目的意思，再考虑了【base中是否有人既没有被AP也没有被DL】之后，再一次考虑【for each approved or declined】:*/
SELECT A.* FROM
(SELECT B.acct_num, D.decision_status, L.letter_code, SUBSTRING(D.decision_date,1,7) AS des, SUBSTRING(L.Letter_trigger_date,1,7) AS trig
FROM base AS B
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number
WHERE  D.decision_status IS NOT NULL) AS A 
WHERE A.des<=A.trig or A.trig IS NULL;
/*所以就当是，加入base仅仅只是为了，运用到base当中的信息罢了；而因为LEFT JOIN了base，所以还是要加上WHERE  D.decision_status IS NOT NULL以及A.trig IS NULL作为保险措施*/

-- 4.2
/*错的原因是：【check是一个reserved word】，所以不可以用check当作是变量名！！！！*/
SELECT A.* FROM
(SELECT B.acct_num, D.decision_status, D.decision_date, L.Letter_trigger_date, L.letter_code, L.language,
CASE WHEN (L.language='French' AND (L.letter_code='AE001' OR L.letter_code='RE001')) THEN 'Wrong'
	 WHEN (L.language='English' AND (L.letter_code='AE002' OR L.letter_code='RE002')) THEN 'Wrong'
     ELSE 'Correct' END AS check
FROM base AS B 
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number
WHERE D.decision_status IS NOT NULL) AS A
WHERE check='Wrong';

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

-- 5.
/*【版本一】不浪费之前写过的code，直接把上边几题的code当作一个subquery组合起来～～～*/
/*??????????试一下，答案一样不？？？？？？？？？？？*/
/*【能】run出来，但是，好奇怪😂*/
SELECT B.*, D.decision_status, D.decision_date, L.Letter_trigger_date, L.letter_code, L.language, 
AA.mismatch_flag, CC.missing_letter_flag, DD.wrong_letter_flag
FROM base AS B
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number

LEFT JOIN 
(SELECT base.acct_num AS acc, 
    CASE WHEN (base.credit_limit+base.offer_amount)-credit_limit_after != 0 THEN "1" END AS mismatch_flag
	FROM base 
	LEFT JOIN decision AS d ON base.acct_num=d.acct_decision_id
	LEFT JOIN change_record AS c ON base.acct_num=c.account_number
	WHERE decision_status='AP')
AS AA ON B.acct_num=AA.acc

LEFT JOIN
(SELECT B.acct_num AS acc, 
    CASE WHEN SUBSTRING(D.decision_date,1,7)>SUBSTRING(L.Letter_trigger_date,1,7) or L.Letter_trigger_date IS NULL THEN "1" END AS missing_letter_flag
	FROM base AS B
	LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
	LEFT JOIN letter AS L ON B.acct_num=L.account_number
	WHERE D.decision_status IS NOT NULL)
AS CC ON B.acct_num=CC.acc

LEFT JOIN
(SELECT B.acct_num AS acc,
CASE WHEN (L.language='French' AND (L.letter_code='AE001' OR L.letter_code='RE001')) THEN '1'
	 WHEN (L.language='English' AND (L.letter_code='AE002' OR L.letter_code='RE002')) THEN '1'
     ELSE '0' END AS wrong_letter_flag
FROM base AS B
LEFT JOIN decision AS D ON B.acct_num=D.acct_decision_id
LEFT JOIN letter AS L ON B.acct_num=L.account_number
WHERE  D.decision_status IS NOT NULL)
AS DD ON B.acct_num=DD.acc;

/*加入直接做第五道题的话，既不用derived table的话：*/
/*【版本二】👌👌，而且其实版本一也是OK的，只是看起来没有版本二舒服😂*/
/*但是上一张截图有一个小错误：现在修好啦！*/
/*PS:我这边把没有response的客户，也当作是missing letter哦～*/
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




