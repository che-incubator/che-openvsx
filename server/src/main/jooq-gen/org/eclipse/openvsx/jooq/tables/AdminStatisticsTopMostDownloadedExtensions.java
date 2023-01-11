/*
 * This file is generated by jOOQ.
 */
package org.eclipse.openvsx.jooq.tables;


import java.util.Arrays;
import java.util.List;

import org.eclipse.openvsx.jooq.Keys;
import org.eclipse.openvsx.jooq.Public;
import org.eclipse.openvsx.jooq.tables.records.AdminStatisticsTopMostDownloadedExtensionsRecord;
import org.jooq.Field;
import org.jooq.ForeignKey;
import org.jooq.Name;
import org.jooq.Record;
import org.jooq.Row3;
import org.jooq.Schema;
import org.jooq.Table;
import org.jooq.TableField;
import org.jooq.TableOptions;
import org.jooq.impl.DSL;
import org.jooq.impl.SQLDataType;
import org.jooq.impl.TableImpl;


/**
 * This class is generated by jOOQ.
 */
@SuppressWarnings({ "all", "unchecked", "rawtypes" })
public class AdminStatisticsTopMostDownloadedExtensions extends TableImpl<AdminStatisticsTopMostDownloadedExtensionsRecord> {

    private static final long serialVersionUID = 1L;

    /**
     * The reference instance of <code>public.admin_statistics_top_most_downloaded_extensions</code>
     */
    public static final AdminStatisticsTopMostDownloadedExtensions ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS = new AdminStatisticsTopMostDownloadedExtensions();

    /**
     * The class holding records for this type
     */
    @Override
    public Class<AdminStatisticsTopMostDownloadedExtensionsRecord> getRecordType() {
        return AdminStatisticsTopMostDownloadedExtensionsRecord.class;
    }

    /**
     * The column <code>public.admin_statistics_top_most_downloaded_extensions.admin_statistics_id</code>.
     */
    public final TableField<AdminStatisticsTopMostDownloadedExtensionsRecord, Long> ADMIN_STATISTICS_ID = createField(DSL.name("admin_statistics_id"), SQLDataType.BIGINT.nullable(false), this, "");

    /**
     * The column <code>public.admin_statistics_top_most_downloaded_extensions.extension_identifier</code>.
     */
    public final TableField<AdminStatisticsTopMostDownloadedExtensionsRecord, String> EXTENSION_IDENTIFIER = createField(DSL.name("extension_identifier"), SQLDataType.VARCHAR(255).nullable(false), this, "");

    /**
     * The column <code>public.admin_statistics_top_most_downloaded_extensions.downloads</code>.
     */
    public final TableField<AdminStatisticsTopMostDownloadedExtensionsRecord, Long> DOWNLOADS = createField(DSL.name("downloads"), SQLDataType.BIGINT.nullable(false), this, "");

    private AdminStatisticsTopMostDownloadedExtensions(Name alias, Table<AdminStatisticsTopMostDownloadedExtensionsRecord> aliased) {
        this(alias, aliased, null);
    }

    private AdminStatisticsTopMostDownloadedExtensions(Name alias, Table<AdminStatisticsTopMostDownloadedExtensionsRecord> aliased, Field<?>[] parameters) {
        super(alias, null, aliased, parameters, DSL.comment(""), TableOptions.table());
    }

    /**
     * Create an aliased <code>public.admin_statistics_top_most_downloaded_extensions</code> table reference
     */
    public AdminStatisticsTopMostDownloadedExtensions(String alias) {
        this(DSL.name(alias), ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS);
    }

    /**
     * Create an aliased <code>public.admin_statistics_top_most_downloaded_extensions</code> table reference
     */
    public AdminStatisticsTopMostDownloadedExtensions(Name alias) {
        this(alias, ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS);
    }

    /**
     * Create a <code>public.admin_statistics_top_most_downloaded_extensions</code> table reference
     */
    public AdminStatisticsTopMostDownloadedExtensions() {
        this(DSL.name("admin_statistics_top_most_downloaded_extensions"), null);
    }

    public <O extends Record> AdminStatisticsTopMostDownloadedExtensions(Table<O> child, ForeignKey<O, AdminStatisticsTopMostDownloadedExtensionsRecord> key) {
        super(child, key, ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS);
    }

    @Override
    public Schema getSchema() {
        return Public.PUBLIC;
    }

    @Override
    public List<ForeignKey<AdminStatisticsTopMostDownloadedExtensionsRecord, ?>> getReferences() {
        return Arrays.<ForeignKey<AdminStatisticsTopMostDownloadedExtensionsRecord, ?>>asList(Keys.ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS__ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS_FKEY);
    }

    private transient AdminStatistics _adminStatistics;

    public AdminStatistics adminStatistics() {
        if (_adminStatistics == null)
            _adminStatistics = new AdminStatistics(this, Keys.ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS__ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS_FKEY);

        return _adminStatistics;
    }

    @Override
    public AdminStatisticsTopMostDownloadedExtensions as(String alias) {
        return new AdminStatisticsTopMostDownloadedExtensions(DSL.name(alias), this);
    }

    @Override
    public AdminStatisticsTopMostDownloadedExtensions as(Name alias) {
        return new AdminStatisticsTopMostDownloadedExtensions(alias, this);
    }

    /**
     * Rename this table
     */
    @Override
    public AdminStatisticsTopMostDownloadedExtensions rename(String name) {
        return new AdminStatisticsTopMostDownloadedExtensions(DSL.name(name), null);
    }

    /**
     * Rename this table
     */
    @Override
    public AdminStatisticsTopMostDownloadedExtensions rename(Name name) {
        return new AdminStatisticsTopMostDownloadedExtensions(name, null);
    }

    // -------------------------------------------------------------------------
    // Row3 type methods
    // -------------------------------------------------------------------------

    @Override
    public Row3<Long, String, Long> fieldsRow() {
        return (Row3) super.fieldsRow();
    }
}
