/*
 * This file is generated by jOOQ.
 */
package org.eclipse.openvsx.jooq.tables.records;


import org.eclipse.openvsx.jooq.tables.AdminStatisticsExtensionsByRating;
import org.jooq.Field;
import org.jooq.Record3;
import org.jooq.Row3;
import org.jooq.impl.TableRecordImpl;


/**
 * This class is generated by jOOQ.
 */
@SuppressWarnings({ "all", "unchecked", "rawtypes" })
public class AdminStatisticsExtensionsByRatingRecord extends TableRecordImpl<AdminStatisticsExtensionsByRatingRecord> implements Record3<Long, Integer, Integer> {

    private static final long serialVersionUID = 1L;

    /**
     * Setter for
     * <code>public.admin_statistics_extensions_by_rating.admin_statistics_id</code>.
     */
    public void setAdminStatisticsId(Long value) {
        set(0, value);
    }

    /**
     * Getter for
     * <code>public.admin_statistics_extensions_by_rating.admin_statistics_id</code>.
     */
    public Long getAdminStatisticsId() {
        return (Long) get(0);
    }

    /**
     * Setter for
     * <code>public.admin_statistics_extensions_by_rating.rating</code>.
     */
    public void setRating(Integer value) {
        set(1, value);
    }

    /**
     * Getter for
     * <code>public.admin_statistics_extensions_by_rating.rating</code>.
     */
    public Integer getRating() {
        return (Integer) get(1);
    }

    /**
     * Setter for
     * <code>public.admin_statistics_extensions_by_rating.extensions</code>.
     */
    public void setExtensions(Integer value) {
        set(2, value);
    }

    /**
     * Getter for
     * <code>public.admin_statistics_extensions_by_rating.extensions</code>.
     */
    public Integer getExtensions() {
        return (Integer) get(2);
    }

    // -------------------------------------------------------------------------
    // Record3 type implementation
    // -------------------------------------------------------------------------

    @Override
    public Row3<Long, Integer, Integer> fieldsRow() {
        return (Row3) super.fieldsRow();
    }

    @Override
    public Row3<Long, Integer, Integer> valuesRow() {
        return (Row3) super.valuesRow();
    }

    @Override
    public Field<Long> field1() {
        return AdminStatisticsExtensionsByRating.ADMIN_STATISTICS_EXTENSIONS_BY_RATING.ADMIN_STATISTICS_ID;
    }

    @Override
    public Field<Integer> field2() {
        return AdminStatisticsExtensionsByRating.ADMIN_STATISTICS_EXTENSIONS_BY_RATING.RATING;
    }

    @Override
    public Field<Integer> field3() {
        return AdminStatisticsExtensionsByRating.ADMIN_STATISTICS_EXTENSIONS_BY_RATING.EXTENSIONS;
    }

    @Override
    public Long component1() {
        return getAdminStatisticsId();
    }

    @Override
    public Integer component2() {
        return getRating();
    }

    @Override
    public Integer component3() {
        return getExtensions();
    }

    @Override
    public Long value1() {
        return getAdminStatisticsId();
    }

    @Override
    public Integer value2() {
        return getRating();
    }

    @Override
    public Integer value3() {
        return getExtensions();
    }

    @Override
    public AdminStatisticsExtensionsByRatingRecord value1(Long value) {
        setAdminStatisticsId(value);
        return this;
    }

    @Override
    public AdminStatisticsExtensionsByRatingRecord value2(Integer value) {
        setRating(value);
        return this;
    }

    @Override
    public AdminStatisticsExtensionsByRatingRecord value3(Integer value) {
        setExtensions(value);
        return this;
    }

    @Override
    public AdminStatisticsExtensionsByRatingRecord values(Long value1, Integer value2, Integer value3) {
        value1(value1);
        value2(value2);
        value3(value3);
        return this;
    }

    // -------------------------------------------------------------------------
    // Constructors
    // -------------------------------------------------------------------------

    /**
     * Create a detached AdminStatisticsExtensionsByRatingRecord
     */
    public AdminStatisticsExtensionsByRatingRecord() {
        super(AdminStatisticsExtensionsByRating.ADMIN_STATISTICS_EXTENSIONS_BY_RATING);
    }

    /**
     * Create a detached, initialised AdminStatisticsExtensionsByRatingRecord
     */
    public AdminStatisticsExtensionsByRatingRecord(Long adminStatisticsId, Integer rating, Integer extensions) {
        super(AdminStatisticsExtensionsByRating.ADMIN_STATISTICS_EXTENSIONS_BY_RATING);

        setAdminStatisticsId(adminStatisticsId);
        setRating(rating);
        setExtensions(extensions);
        resetChangedOnNotNull();
    }
}
