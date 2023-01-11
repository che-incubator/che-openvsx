/*
 * This file is generated by jOOQ.
 */
package org.eclipse.openvsx.jooq.tables;


import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import org.eclipse.openvsx.jooq.Indexes;
import org.eclipse.openvsx.jooq.Keys;
import org.eclipse.openvsx.jooq.Public;
import org.eclipse.openvsx.jooq.tables.records.ExtensionReviewRecord;
import org.jooq.Field;
import org.jooq.ForeignKey;
import org.jooq.Index;
import org.jooq.Name;
import org.jooq.Record;
import org.jooq.Row8;
import org.jooq.Schema;
import org.jooq.Table;
import org.jooq.TableField;
import org.jooq.TableOptions;
import org.jooq.UniqueKey;
import org.jooq.impl.DSL;
import org.jooq.impl.SQLDataType;
import org.jooq.impl.TableImpl;


/**
 * This class is generated by jOOQ.
 */
@SuppressWarnings({ "all", "unchecked", "rawtypes" })
public class ExtensionReview extends TableImpl<ExtensionReviewRecord> {

    private static final long serialVersionUID = 1L;

    /**
     * The reference instance of <code>public.extension_review</code>
     */
    public static final ExtensionReview EXTENSION_REVIEW = new ExtensionReview();

    /**
     * The class holding records for this type
     */
    @Override
    public Class<ExtensionReviewRecord> getRecordType() {
        return ExtensionReviewRecord.class;
    }

    /**
     * The column <code>public.extension_review.id</code>.
     */
    public final TableField<ExtensionReviewRecord, Long> ID = createField(DSL.name("id"), SQLDataType.BIGINT.nullable(false), this, "");

    /**
     * The column <code>public.extension_review.active</code>.
     */
    public final TableField<ExtensionReviewRecord, Boolean> ACTIVE = createField(DSL.name("active"), SQLDataType.BOOLEAN.nullable(false), this, "");

    /**
     * The column <code>public.extension_review.comment</code>.
     */
    public final TableField<ExtensionReviewRecord, String> COMMENT = createField(DSL.name("comment"), SQLDataType.VARCHAR(2048), this, "");

    /**
     * The column <code>public.extension_review.rating</code>.
     */
    public final TableField<ExtensionReviewRecord, Integer> RATING = createField(DSL.name("rating"), SQLDataType.INTEGER.nullable(false), this, "");

    /**
     * The column <code>public.extension_review.timestamp</code>.
     */
    public final TableField<ExtensionReviewRecord, LocalDateTime> TIMESTAMP = createField(DSL.name("timestamp"), SQLDataType.LOCALDATETIME(6), this, "");

    /**
     * The column <code>public.extension_review.title</code>.
     */
    public final TableField<ExtensionReviewRecord, String> TITLE = createField(DSL.name("title"), SQLDataType.VARCHAR(255), this, "");

    /**
     * The column <code>public.extension_review.extension_id</code>.
     */
    public final TableField<ExtensionReviewRecord, Long> EXTENSION_ID = createField(DSL.name("extension_id"), SQLDataType.BIGINT, this, "");

    /**
     * The column <code>public.extension_review.user_id</code>.
     */
    public final TableField<ExtensionReviewRecord, Long> USER_ID = createField(DSL.name("user_id"), SQLDataType.BIGINT, this, "");

    private ExtensionReview(Name alias, Table<ExtensionReviewRecord> aliased) {
        this(alias, aliased, null);
    }

    private ExtensionReview(Name alias, Table<ExtensionReviewRecord> aliased, Field<?>[] parameters) {
        super(alias, null, aliased, parameters, DSL.comment(""), TableOptions.table());
    }

    /**
     * Create an aliased <code>public.extension_review</code> table reference
     */
    public ExtensionReview(String alias) {
        this(DSL.name(alias), EXTENSION_REVIEW);
    }

    /**
     * Create an aliased <code>public.extension_review</code> table reference
     */
    public ExtensionReview(Name alias) {
        this(alias, EXTENSION_REVIEW);
    }

    /**
     * Create a <code>public.extension_review</code> table reference
     */
    public ExtensionReview() {
        this(DSL.name("extension_review"), null);
    }

    public <O extends Record> ExtensionReview(Table<O> child, ForeignKey<O, ExtensionReviewRecord> key) {
        super(child, key, EXTENSION_REVIEW);
    }

    @Override
    public Schema getSchema() {
        return Public.PUBLIC;
    }

    @Override
    public List<Index> getIndexes() {
        return Arrays.<Index>asList(Indexes.EXTENSION_REVIEW__EXTENSION_ID__IDX, Indexes.EXTENSION_REVIEW__USER_ID__IDX);
    }

    @Override
    public UniqueKey<ExtensionReviewRecord> getPrimaryKey() {
        return Keys.EXTENSION_REVIEW_PKEY;
    }

    @Override
    public List<UniqueKey<ExtensionReviewRecord>> getKeys() {
        return Arrays.<UniqueKey<ExtensionReviewRecord>>asList(Keys.EXTENSION_REVIEW_PKEY);
    }

    @Override
    public List<ForeignKey<ExtensionReviewRecord, ?>> getReferences() {
        return Arrays.<ForeignKey<ExtensionReviewRecord, ?>>asList(Keys.EXTENSION_REVIEW__FKGD2DQDC23OGBNOBX8AFJFPNKP, Keys.EXTENSION_REVIEW__FKINJBN9GRK135Y6IK0UT4UJP0W);
    }

    private transient Extension _extension;
    private transient UserData _userData;

    public Extension extension() {
        if (_extension == null)
            _extension = new Extension(this, Keys.EXTENSION_REVIEW__FKGD2DQDC23OGBNOBX8AFJFPNKP);

        return _extension;
    }

    public UserData userData() {
        if (_userData == null)
            _userData = new UserData(this, Keys.EXTENSION_REVIEW__FKINJBN9GRK135Y6IK0UT4UJP0W);

        return _userData;
    }

    @Override
    public ExtensionReview as(String alias) {
        return new ExtensionReview(DSL.name(alias), this);
    }

    @Override
    public ExtensionReview as(Name alias) {
        return new ExtensionReview(alias, this);
    }

    /**
     * Rename this table
     */
    @Override
    public ExtensionReview rename(String name) {
        return new ExtensionReview(DSL.name(name), null);
    }

    /**
     * Rename this table
     */
    @Override
    public ExtensionReview rename(Name name) {
        return new ExtensionReview(name, null);
    }

    // -------------------------------------------------------------------------
    // Row8 type methods
    // -------------------------------------------------------------------------

    @Override
    public Row8<Long, Boolean, String, Integer, LocalDateTime, String, Long, Long> fieldsRow() {
        return (Row8) super.fieldsRow();
    }
}
