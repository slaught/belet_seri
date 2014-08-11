-- Start a transaction.
BEGIN;
SELECT plan( 2 );

-- Insert stuff.
SELECT ok(
    now() = now(),
    'insert_stuff() should return true'
);

-- Check for domain stuff records.
SELECT is(
    ARRAY(
        VALUES (1),(2),(3)
    ),
    ARRAY[ 1,2, 3 ],
    'The stuff should have been associated with the domain'
);

SELECT * FROM finish();
ROLLBACK;


