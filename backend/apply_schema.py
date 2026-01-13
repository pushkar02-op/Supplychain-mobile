from sqlalchemy import text

from app.db.session import engine


def apply():
    with engine.connect() as conn:
        print("Creating types...")
        conn.execute(
            text(
                "DO $$ BEGIN CREATE TYPE mismatchtype AS ENUM ('IDENTITY', 'QUANTITY', 'UOM', 'PRICE', 'MISSING_ENTRY', 'MISSING_INVOICE'); EXCEPTION WHEN duplicate_object THEN null; END $$;"
            )
        )
        conn.execute(
            text(
                "DO $$ BEGIN CREATE TYPE mismatchstatus AS ENUM ('OPEN', 'RESOLVED_SYSTEM', 'RESOLVED_MART', 'IGNORED'); EXCEPTION WHEN duplicate_object THEN null; END $$;"
            )
        )

        print("Creating table...")
        conn.execute(
            text(
                """
        CREATE TABLE IF NOT EXISTS reconciliation_mismatch (
            id SERIAL PRIMARY KEY,
            invoice_item_id INTEGER NOT NULL REFERENCES invoice_item(id),
            batch_id INTEGER REFERENCES batch(id),
            mismatch_type mismatchtype NOT NULL,
            system_value JSON,
            mart_value JSON,
            confidence_score FLOAT NOT NULL,
            status mismatchstatus NOT NULL,
            resolution_notes VARCHAR,
            created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
            updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
            resolved_at TIMESTAMP WITHOUT TIME ZONE,
            resolved_by VARCHAR
        );
        """
            )
        )

        print("Creating indices...")
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_reconciliation_mismatch_invoice_item_id ON reconciliation_mismatch (invoice_item_id);"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_reconciliation_mismatch_batch_id ON reconciliation_mismatch (batch_id);"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_reconciliation_mismatch_status ON reconciliation_mismatch (status);"
            )
        )

        conn.commit()
        print("Schema applied successfully.")


if __name__ == "__main__":
    apply()
