-- sqlite3 IgorProfiles.db
-- Then paste the code below.

-- sqlite doesn't know/care about VARCHAR, but use it for portability.
CREATE TABLE profile (
    nick        VARCHAR(30)  PRIMARY KEY,
    age         VARCHAR(66)  CHECK (LENGTH(age)     > 0),
    sex         VARCHAR(66)  CHECK (LENGTH(sex)     > 0),
    loc         VARCHAR(66)  CHECK (LENGTH(loc)     > 0),
    bdsm        VARCHAR(66)  CHECK (LENGTH(bdsm)    > 0),
    limits      VARCHAR(410) CHECK (LENGTH(limits)  > 0),
    kinks       VARCHAR(410) CHECK (LENGTH(kinks)   > 0),
    fantasy     VARCHAR(410) CHECK (LENGTH(fantasy) > 0),
    desc        VARCHAR(410) CHECK (LENGTH(desc)    > 0),
    intro       VARCHAR(410) CHECK (LENGTH(intro)   > 0),
    quote       VARCHAR(410) CHECK (LENGTH(quote)   > 0),
    fanfare     INTEGER,
    last_access DATE
);

-- As above for DATE
CREATE TABLE ban (
    id INTEGER PRIMARY KEY,
    mask     TEXT NOT NULL,
    set_on   DATE,
    lift_on  DATE NOT NULL,
    duration INTEGER,
    units    TEXT,
    set_by   TEXT NOT NULL,
    reason   TEXT NOT NULL,
    expired  BOOLEAN NOT NULL DEFAULT 0
);

CREATE TABLE intro_pool (
    id INTEGER PRIMARY KEY,
    given_by VARCHAR(30),
    saved_on DATE DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    content VARCHAR(300) UNIQUE -- Won't catch white-space or capitalization
);

CREATE TRIGGER
    new_profile
AFTER INSERT ON
    profile
BEGIN
    UPDATE
        profile
    SET
        last_access = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE
        nick = new.nick AND new.last_access IS NULL;
END;

CREATE TRIGGER
    mod_profile
AFTER UPDATE OF
    age, sex, loc, bdsm, kinks, limits, fantasy, desc, fanfare
ON
    profile
BEGIN
    UPDATE
        profile
    SET
        last_access = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE
        nick = new.nick;
END;

/*
    Then do this from the command line...

dbicdump -o dump_directory=./lib -o use_moose=1 \
    Igor::Schema dbi:SQLite:./IgorProfiles.db

*/
