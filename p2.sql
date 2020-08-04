--connect to cs157a@
--connect to cs157a@
CONNECT TO CS157A@

DROP PROCEDURE P2.CUST_CRT@
DROP PROCEDURE P2.CUST_LOGIN@
DROP PROCEDURE P2.ACCT_OPN@
DROP PROCEDURE P2.ACCT_CLS@
DROP PROCEDURE P2.ACCT_DEP@
DROP PROCEDURE P2.ACCT_WTH@
DROP PROCEDURE P2.ACCT_TRX@
DROP PROCEDURE P2.ADD_INTEREST@



CREATE PROCEDURE P2.CUST_CRT(IN name1 VARCHAR(15), IN gender CHAR, IN age INTEGER, IN pin INTEGER, OUT id INTEGER, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
    DECLARE crt_error CONDITION FOR SQLSTATE '22001';
    DECLARE CONTINUE HANDLER FOR crt_error
      BEGIN
        SET sql_code=10;
        SET err_msg='Name too long. Name must be shortened to 15 characters.';
      END;
    IF (age>=0 AND pin>=0) THEN
      INSERT INTO p2.customer (name, gender, age, pin) VALUES(name1, gender, age, p2.encrypt(pin));
      SET id=(select max(id) from p2.customer);
    ELSE
      SET err_msg='Please ensure that age and pin are greater than 0.';
      SET sql_code=11;
    END IF;
    COMMIT;
END @


CREATE PROCEDURE P2.CUST_LOGIN(IN id1 INTEGER, IN pin1 INTEGER, OUT valid INTEGER, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
  IF EXISTS (select * from p2.customer where id=id1) THEN
    IF (pin1=(select p2.decrypt(pin) from p2.customer where pin=p2.encrypt(pin1) and id=id1)) THEN
     SET valid=1;
    ELSE
     SET valid=0;
     SET sql_code=13;
     SET err_msg='Invalid pin. Please try again.';
    END IF;
  ELSE
    SET valid=0;
    SET sql_code=12;
    SET err_msg='Invalid ID. Please try again.';
  END IF;
END @


CREATE PROCEDURE P2.ACCT_OPN(IN id1 INTEGER, IN balance INTEGER, IN type1 CHAR, OUT number INTEGER, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
  DECLARE error_cond CONDITION FOR SQLSTATE '23503';
  DECLARE CONTINUE HANDLER FOR error_cond
    BEGIN
      SET err_msg = 'Invalid ID. Please try again.';
      SET sql_code=12;
    END;
  IF (id1>=100 AND balance>=0 AND type1 in ('C','S')) THEN
    INSERT INTO p2.account (id, balance, type, status) VALUES(id1, balance, type1, 'A');
    SET number=(select max(number) from p2.account where id=id1);
  ELSE
    SET sql_code=14;
    SET err_msg='Unable to open account. Please ensure that initial balance (deposit) is greater than or equal to 0 and that the type of account is C for checking or S for savings.';
    END IF;
  COMMIT;
END @


CREATE PROCEDURE P2.ACCT_CLS(IN number1 INTEGER, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
  IF EXISTS (select * from p2.account where number=number1) THEN
    IF ('A'=(select status from p2.account where number=number1)) THEN
      UPDATE p2.account SET status = 'I', balance=0 WHERE number=number1;
    ELSE
     SET sql_code=16;
     SET err_msg='Account is already closed.';
    END IF;
  ELSE
    SET sql_code=15;
    SET err_msg='Account does not exist. Please try again.';
  END IF;
  COMMIT;
END @


CREATE PROCEDURE P2.ACCT_DEP(IN number1 INTEGER, IN amount INTEGER, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
  DECLARE deposit_error CONDITION FOR SQLSTATE '02000';
  DECLARE CONTINUE HANDLER FOR deposit_error
    BEGIN
    SET sql_code=17;
    SET err_msg='Unable to deposit because account number is not associated with an active account.';
    END;
  IF (amount>=0) THEN
    UPDATE p2.account SET balance = balance + amount WHERE number=number1 and status='A';
  ELSE
    SET sql_code=18;
    SET err_msg='Unable to deposit. Deposit amount must be a positive value.';
  END IF;
  COMMIT;
END @


CREATE PROCEDURE P2.ACCT_WTH(IN number1 INTEGER, IN amount INTEGER, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
  IF (amount>=0) THEN
    IF EXISTS (select * from p2.account where number=number1 AND status='A') THEN
      IF (amount<(select balance from p2.account where number=number1)) THEN
        UPDATE p2.account SET balance = balance - amount WHERE number=number1 and status='A';
      ELSE
        SET sql_code=19;
        SET err_msg='Unable to withdraw. Insufficient funds.';
      END IF;
    ELSE
      SET sql_code=20;
      SET err_msg='Unable to withdraw because account number is not associated with an active account.';
    END IF;
  ELSE
    SET sql_code=21;
    SET err_msg='Unable to withdraw. Withdrawal amount must be a positive value.';
  END IF;
  COMMIT;
END @


CREATE PROCEDURE P2.ACCT_TRX(IN src_acct INTEGER, IN dest_acct INTEGER, IN amt INTEGER, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
  DECLARE with_sql_code INTEGER;
  DECLARE with_err_msg VARCHAR(200);
  DECLARE dep_sql_code INTEGER;
  DECLARE dep_err_msg VARCHAR(200);
  IF ((SELECT id FROM p2.account WHERE number=src_acct AND status='A')=(SELECT id FROM p2.account WHERE number=dest_acct AND status='A')) THEN 
    CALL p2.ACCT_WTH(src_acct, amt, with_sql_code, with_err_msg);
    SET sql_code=with_sql_code;
    SET err_msg=with_err_msg;
    CALL p2.ACCT_DEP(dest_acct, amt, dep_sql_code, dep_err_msg);
    SET sql_code=dep_sql_code;
    SET err_msg=dep_err_msg;
  ELSE
    SET sql_code=22;
    SET err_msg='Please ensure that the same customer owns both the source and destination accounts and that both accounts are listed as active.';
  END IF;
  COMMIT;
END @


CREATE PROCEDURE P2.ADD_INTEREST(IN savings_rate FLOAT, IN checking_rate FLOAT, OUT sql_code INTEGER, OUT err_msg VARCHAR(500))
LANGUAGE SQL
  BEGIN
  IF (savings_rate BETWEEN 0 AND 1 AND checking_rate BETWEEN 0 AND 1) THEN
    UPDATE p2.account SET balance = balance + balance*savings_rate WHERE type='S' AND status='A';
    UPDATE p2.account SET balance = balance + balance*checking_rate WHERE type='C' AND status='A';
  ELSE
    SET sql_code=23;
    SET err_msg='Unable to add interest. Please ensure that interest rates are between 0 and 1.';
  END IF;
  COMMIT;
END @
TERMINATE @
