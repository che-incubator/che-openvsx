/*
 * This file is generated by jOOQ.
 */
package org.eclipse.openvsx.jooq;


import org.eclipse.openvsx.jooq.tables.AdminStatistics;
import org.eclipse.openvsx.jooq.tables.AdminStatisticsExtensionsByRating;
import org.eclipse.openvsx.jooq.tables.AdminStatisticsPublishersByExtensionsPublished;
import org.eclipse.openvsx.jooq.tables.AdminStatisticsTopMostActivePublishingUsers;
import org.eclipse.openvsx.jooq.tables.AdminStatisticsTopMostDownloadedExtensions;
import org.eclipse.openvsx.jooq.tables.AdminStatisticsTopNamespaceExtensionVersions;
import org.eclipse.openvsx.jooq.tables.AdminStatisticsTopNamespaceExtensions;
import org.eclipse.openvsx.jooq.tables.AzureDownloadCountProcessedItem;
import org.eclipse.openvsx.jooq.tables.Download;
import org.eclipse.openvsx.jooq.tables.EntityActiveState;
import org.eclipse.openvsx.jooq.tables.Extension;
import org.eclipse.openvsx.jooq.tables.ExtensionReview;
import org.eclipse.openvsx.jooq.tables.ExtensionVersion;
import org.eclipse.openvsx.jooq.tables.FileResource;
import org.eclipse.openvsx.jooq.tables.FlywaySchemaHistory;
import org.eclipse.openvsx.jooq.tables.JobrunrBackgroundjobservers;
import org.eclipse.openvsx.jooq.tables.JobrunrJobs;
import org.eclipse.openvsx.jooq.tables.JobrunrJobsStats;
import org.eclipse.openvsx.jooq.tables.JobrunrMetadata;
import org.eclipse.openvsx.jooq.tables.JobrunrMigrations;
import org.eclipse.openvsx.jooq.tables.JobrunrRecurringJobs;
import org.eclipse.openvsx.jooq.tables.MigrationItem;
import org.eclipse.openvsx.jooq.tables.Namespace;
import org.eclipse.openvsx.jooq.tables.NamespaceMembership;
import org.eclipse.openvsx.jooq.tables.PersistedLog;
import org.eclipse.openvsx.jooq.tables.PersonalAccessToken;
import org.eclipse.openvsx.jooq.tables.Shedlock;
import org.eclipse.openvsx.jooq.tables.SpringSession;
import org.eclipse.openvsx.jooq.tables.SpringSessionAttributes;
import org.eclipse.openvsx.jooq.tables.UserData;


/**
 * Convenience access to all tables in public.
 */
@SuppressWarnings({ "all", "unchecked", "rawtypes" })
public class Tables {

    /**
     * The table <code>public.admin_statistics</code>.
     */
    public static final AdminStatistics ADMIN_STATISTICS = AdminStatistics.ADMIN_STATISTICS;

    /**
     * The table <code>public.admin_statistics_extensions_by_rating</code>.
     */
    public static final AdminStatisticsExtensionsByRating ADMIN_STATISTICS_EXTENSIONS_BY_RATING = AdminStatisticsExtensionsByRating.ADMIN_STATISTICS_EXTENSIONS_BY_RATING;

    /**
     * The table <code>public.admin_statistics_publishers_by_extensions_published</code>.
     */
    public static final AdminStatisticsPublishersByExtensionsPublished ADMIN_STATISTICS_PUBLISHERS_BY_EXTENSIONS_PUBLISHED = AdminStatisticsPublishersByExtensionsPublished.ADMIN_STATISTICS_PUBLISHERS_BY_EXTENSIONS_PUBLISHED;

    /**
     * The table <code>public.admin_statistics_top_most_active_publishing_users</code>.
     */
    public static final AdminStatisticsTopMostActivePublishingUsers ADMIN_STATISTICS_TOP_MOST_ACTIVE_PUBLISHING_USERS = AdminStatisticsTopMostActivePublishingUsers.ADMIN_STATISTICS_TOP_MOST_ACTIVE_PUBLISHING_USERS;

    /**
     * The table <code>public.admin_statistics_top_most_downloaded_extensions</code>.
     */
    public static final AdminStatisticsTopMostDownloadedExtensions ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS = AdminStatisticsTopMostDownloadedExtensions.ADMIN_STATISTICS_TOP_MOST_DOWNLOADED_EXTENSIONS;

    /**
     * The table <code>public.admin_statistics_top_namespace_extension_versions</code>.
     */
    public static final AdminStatisticsTopNamespaceExtensionVersions ADMIN_STATISTICS_TOP_NAMESPACE_EXTENSION_VERSIONS = AdminStatisticsTopNamespaceExtensionVersions.ADMIN_STATISTICS_TOP_NAMESPACE_EXTENSION_VERSIONS;

    /**
     * The table <code>public.admin_statistics_top_namespace_extensions</code>.
     */
    public static final AdminStatisticsTopNamespaceExtensions ADMIN_STATISTICS_TOP_NAMESPACE_EXTENSIONS = AdminStatisticsTopNamespaceExtensions.ADMIN_STATISTICS_TOP_NAMESPACE_EXTENSIONS;

    /**
     * The table <code>public.azure_download_count_processed_item</code>.
     */
    public static final AzureDownloadCountProcessedItem AZURE_DOWNLOAD_COUNT_PROCESSED_ITEM = AzureDownloadCountProcessedItem.AZURE_DOWNLOAD_COUNT_PROCESSED_ITEM;

    /**
     * The table <code>public.download</code>.
     */
    public static final Download DOWNLOAD = Download.DOWNLOAD;

    /**
     * The table <code>public.entity_active_state</code>.
     */
    public static final EntityActiveState ENTITY_ACTIVE_STATE = EntityActiveState.ENTITY_ACTIVE_STATE;

    /**
     * The table <code>public.extension</code>.
     */
    public static final Extension EXTENSION = Extension.EXTENSION;

    /**
     * The table <code>public.extension_review</code>.
     */
    public static final ExtensionReview EXTENSION_REVIEW = ExtensionReview.EXTENSION_REVIEW;

    /**
     * The table <code>public.extension_version</code>.
     */
    public static final ExtensionVersion EXTENSION_VERSION = ExtensionVersion.EXTENSION_VERSION;

    /**
     * The table <code>public.file_resource</code>.
     */
    public static final FileResource FILE_RESOURCE = FileResource.FILE_RESOURCE;

    /**
     * The table <code>public.flyway_schema_history</code>.
     */
    public static final FlywaySchemaHistory FLYWAY_SCHEMA_HISTORY = FlywaySchemaHistory.FLYWAY_SCHEMA_HISTORY;

    /**
     * The table <code>public.jobrunr_backgroundjobservers</code>.
     */
    public static final JobrunrBackgroundjobservers JOBRUNR_BACKGROUNDJOBSERVERS = JobrunrBackgroundjobservers.JOBRUNR_BACKGROUNDJOBSERVERS;

    /**
     * The table <code>public.jobrunr_jobs</code>.
     */
    public static final JobrunrJobs JOBRUNR_JOBS = JobrunrJobs.JOBRUNR_JOBS;

    /**
     * The table <code>public.jobrunr_jobs_stats</code>.
     */
    public static final JobrunrJobsStats JOBRUNR_JOBS_STATS = JobrunrJobsStats.JOBRUNR_JOBS_STATS;

    /**
     * The table <code>public.jobrunr_metadata</code>.
     */
    public static final JobrunrMetadata JOBRUNR_METADATA = JobrunrMetadata.JOBRUNR_METADATA;

    /**
     * The table <code>public.jobrunr_migrations</code>.
     */
    public static final JobrunrMigrations JOBRUNR_MIGRATIONS = JobrunrMigrations.JOBRUNR_MIGRATIONS;

    /**
     * The table <code>public.jobrunr_recurring_jobs</code>.
     */
    public static final JobrunrRecurringJobs JOBRUNR_RECURRING_JOBS = JobrunrRecurringJobs.JOBRUNR_RECURRING_JOBS;

    /**
     * The table <code>public.migration_item</code>.
     */
    public static final MigrationItem MIGRATION_ITEM = MigrationItem.MIGRATION_ITEM;

    /**
     * The table <code>public.namespace</code>.
     */
    public static final Namespace NAMESPACE = Namespace.NAMESPACE;

    /**
     * The table <code>public.namespace_membership</code>.
     */
    public static final NamespaceMembership NAMESPACE_MEMBERSHIP = NamespaceMembership.NAMESPACE_MEMBERSHIP;

    /**
     * The table <code>public.persisted_log</code>.
     */
    public static final PersistedLog PERSISTED_LOG = PersistedLog.PERSISTED_LOG;

    /**
     * The table <code>public.personal_access_token</code>.
     */
    public static final PersonalAccessToken PERSONAL_ACCESS_TOKEN = PersonalAccessToken.PERSONAL_ACCESS_TOKEN;

    /**
     * The table <code>public.shedlock</code>.
     */
    public static final Shedlock SHEDLOCK = Shedlock.SHEDLOCK;

    /**
     * The table <code>public.spring_session</code>.
     */
    public static final SpringSession SPRING_SESSION = SpringSession.SPRING_SESSION;

    /**
     * The table <code>public.spring_session_attributes</code>.
     */
    public static final SpringSessionAttributes SPRING_SESSION_ATTRIBUTES = SpringSessionAttributes.SPRING_SESSION_ATTRIBUTES;

    /**
     * The table <code>public.user_data</code>.
     */
    public static final UserData USER_DATA = UserData.USER_DATA;
}
