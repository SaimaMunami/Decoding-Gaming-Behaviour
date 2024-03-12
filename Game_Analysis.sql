
use game_analysis;

-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.

alter table player_details modify L1_Status varchar(30);
alter table player_details modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;
select * from player_details;
alter table level_details2 drop myunknowncolumn;
alter table level_details2 change timestamp start_datetime datetime;
alter table level_details2 modify Dev_Id varchar(10);
alter table level_details2 modify Difficulty varchar(15);
select start_datetime from level_details2;
alter table level_details2 add primary key(P_ID,Dev_id,start_datetime);

-- pd (P_ID,PName,L1_status,L2_Status,L1_code,L2_Code)
-- ld (P_ID,Dev_ID,start_time,stages_crossed,level,difficulty,kill_count,
-- headshots_count,score,lives_earned)
-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0
select player_details.p_id,dev_id,pname, difficulty as difficulty_level
from player_details join level_details2 on
player_details.p_id=level_details2.p_id
where level=0;
-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed
select avg(kill_count),player_details.l1_code
from level_details2 join player_details on
level_details2.p_id = player_details.p_id
where lives_earned = 2 and stages_crossed >=3
GROUP BY player_details.l1_code
order by l1_code;
-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level 2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.
select sum(stages_crossed),difficulty
from level_details2
where level =2
group by difficulty
order by sum(stages_crossed) desc;
-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.
select p_id, count(distinct start_datetime) as unique_date
from level_details2
group by p_id
having  count(distinct start_datetime)>1;
-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.
select level_details2.p_id, sum(kill_count)
from  level_details2
where kill_count > (select 
 avg(kill_count) from level_details2
 where difficulty ='medium')
 group by level_details2.p_id;
-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level.
Select level,sum(lives_earned) as total_lives_earned
From level_details2
Where level !=0
Group by level
Order by level;
-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 
SELECT difficulty, MAX(dev_id) AS max_dev_id, MAX(score) AS max_score
FROM level_details2
GROUP BY difficulty
ORDER BY max_score DESC
LIMIT 3;
-- Q8) Find first_login datetime for each device id
select dev_id, min(start_datetime) as first_login
from level_details2
group by dev_id
order by first_login;
-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.
WITH RankedScores AS (
    SELECT
        dev_id,
        difficulty,
        score,
        RANK() OVER (PARTITION BY difficulty ORDER BY score DESC) AS ScoreRank
    FROM
        level_details2
)
SELECT
    dev_id,
    difficulty,
    score,
    ScoreRank
FROM
    RankedScores
WHERE
    ScoreRank <= 5
ORDER BY
    difficulty ASC,
    ScoreRank ASC;

-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.
select p_id,dev_id,min(start_datetime) as first_login_datetime
from level_details2
group by p_id,dev_id
order by first_login_datetime;
-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played -- by the player until that date.
-- a) window function
SELECT p_id, start_datetime, 
SUM(kill_count) OVER (PARTITION BY p_id ORDER BY start_datetime) AS total_kill_count
FROM level_details2
ORDER BY p_id, start_datetime;
-- b) without window function
SELECT ld.p_id,ld.start_datetime,SUM(ld2.kill_count) AS total_kill_count
FROM level_details2 ld
JOIN level_details2 ld2 ON ld.p_id = ld2.p_id
WHERE ld2.start_datetime <= ld.start_datetime
GROUP BY ld.p_id, ld.start_datetime
ORDER BY ld.p_id, ld.start_datetime;
-- Q12) Find the cumulative sum of stages crossed over a start_datetime 
SELECT 
    start_datetime,
    stages_crossed,
    SUM(stages_crossed) OVER (ORDER BY start_datetime) AS cumulative_sum
FROM level_details2;
-- Q13) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime
WITH RankedDetails AS (
    SELECT
        p_id,
        start_datetime,
        stages_crossed,
        ROW_NUMBER() OVER (PARTITION BY p_id ORDER BY start_datetime DESC) AS rn
    FROM
        level_details2
)
SELECT
    p_id,
    start_datetime,
    stages_crossed,
    SUM(CASE WHEN rn > 1 THEN stages_crossed ELSE 0 END) 
        OVER (PARTITION BY p_id ORDER BY start_datetime) AS cumulative_sum
FROM
    RankedDetails;
-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id
WITH RankedScores AS (
    SELECT
        p_id,
        dev_id,
        SUM(score) AS total_score,
        RANK() OVER (PARTITION BY dev_id ORDER BY SUM(score) DESC) AS score_rank
    FROM
       level_details2
    GROUP BY
        p_id, dev_id
)
SELECT
    p_id,
    dev_id,
    total_score
FROM
    RankedScores
WHERE
    score_rank <= 3;
-- Q15) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id
SELECT 
    p_id,
    SUM(score) AS total_score
FROM 
  level_details2
GROUP BY 
    p_id
HAVING 
    SUM(score) > 0.5 * (
        SELECT AVG(sum_score) 
        FROM (
            SELECT 
                p_id, 
                SUM(score) AS sum_score 
            FROM 
                level_details2 
            GROUP BY 
                p_id
        ) AS avg_scores
        WHERE 
            avg_scores.p_id = level_details2.p_id
    );
-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.
-- Q17) Create a function to return sum of Score for a given player_id.
