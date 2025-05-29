# HBase Cluster Setup and WebTable Implementation

## Cluster Architecture

### Hadoop Cluster Components
- **Master Nodes (3)**
  - `master1` (hadoopmaster): Primary NameNode
  - `master2` (hadoopmaster1): Secondary NameNode
  - `master3` (hadoopmaster2): Resource Manager
  - Each master node is allocated 1 CPU core and 2GB memory
  - Exposed ports:
    - NameNode Web UI: 9871, 9872, 9873
    - Resource Manager: 8188, 8288, 8388
    - HDFS: 9000

- **Slave Node (1)**
  - `slave1` (hadoopslave): DataNode
  - Allocated 1 CPU core and 2GB memory

### HBase Components
- **HBase Masters (2)**
  - `hbase-master1` and `hbase-master2`
  - Each master is allocated 1 CPU core and 2GB memory
  - Exposed ports:
    - Master Web UI: 16010, 16011
    - Master Server: 16000, 16001

- **Region Servers (2)**
  - `regionserver1` and `regionserver2`
  - Each region server is allocated 1 CPU core and 2GB memory
  - Exposed ports:
    - Region Server Web UI: 16020, 16021
    - Region Server Info: 16030, 16031

### Storage
- Persistent volumes for:
  - HBase logs: `/var/log/hbase`
  - HBase data: `/hbase/data`

## WebTable Design Decisions

### Table Structure
The WebTable is designed to store web page data with the following characteristics:

1. **Row Key Design**
   - Format: `[salt_bucket]:[reverse_domain]:[reversed_url_path]`
   - Example: `3:com.example:moc/eliame/tset/resource`
   - Salting distributes writes evenly across regions using `MD5(domain + url) % 10`
   - Reversed domain and URL prevents sequential key hotspots
   - Groups pages from the same domain for efficient scans

2. **Column Families**
   | Family     | Versions | TTL      | Compression | In-Memory | Bloom Filter | Use Case                          |
   | ---------- | -------- | -------- | ----------- | --------- | ------------ | --------------------------------- |
   | `content`  | 3        | 90 days  | GZIP        | No        | ROW          | Raw HTML (large, compressible)    |
   | `metadata` | 1        | None     | Snappy      | **Yes**   | ROW          | Title, status code, last modified |
   | `outlinks` | 2        | 180 days | None        | No        | **NONE**     | Outbound links (small strings)    |
   | `inlinks`  | 2        | 180 days | None        | No        | **NONE**     | Inbound links (for SEO analysis)  |

3. **Column Qualifiers**
   - `content:html`: Raw HTML content
   - `content:text`: Extracted text content
   - `metadata:type`: Content type (MIME type)
   - `metadata:language`: Page language
   - `metadata:lastModified`: Last modification timestamp
   - `metadata:status`: HTTP status code
   - `outlinks:list`: List of outbound links
   - `inlinks:list`: List of inbound links

### Performance Optimizations

#### Write Performance
- **MemStore Tuning**:
  - `hbase.hregion.memstore.flush.size = 256MB`
  - `hbase.regionserver.global.memstore.upperLimit = 0.4`
- **WAL Optimization**:
  - `hbase.regionserver.maxlogs = 24`

#### Read Performance
- **Block Cache**:
  - `hfile.block.cache.size = 0.4` (40% of heap)
  - Metadata family marked as in-memory
- **Scanner Caching**:
  - `hbase.client.scanner.caching = 100`
- **Bloom Filters**:
  - ROW level for `content` and `metadata` families
  - Disabled for `inlinks` and `outlinks` (sparse data)

#### Mixed Workload Optimizations
- **Compaction**:
  - Major compactions scheduled during off-peak hours
  - `hbase.hstore.compactionThreshold = 4`

### Access Patterns

#### Content Management (Read-Heavy)
1. **Latest page by URL**:
   ```bash
   get 'webtable', '3:com.example:...', {COLUMN => 'content:html', VERSIONS => 1}
   ```

2. **Historical versions**:
   ```bash
   get 'webtable', '3:com.example:...', {COLUMN => 'content:html', VERSIONS => 3}
   ```

3. **Domain scans**:
   ```bash
   scan 'webtable', {STARTROW => '0:com.example:', ENDROW => '9:com.example;'}
   ```

#### SEO Analysis (Mixed Read/Write)
1. **Inbound links to URL**:
   ```bash
   scan 'webtable', {FILTER => "ValueFilter(=, 'binary:example.com/page1') AND ColumnPrefixFilter('inlinks:')"}
   ```

2. **Dead-end pages**:
   ```bash
   scan 'webtable', {FILTER => "SingleColumnValueFilter('outlinks', 'list', =, 'binary:')"}
   ```

#### Performance Analysis (Scan-Heavy)
1. **Error pages**:
   ```bash
   scan 'webtable', {FILTER => "SingleColumnValueFilter('metadata', 'status', =, 'binary:404')"}
   ```

### Design Justification
1. **Balanced Performance**:
   - Salting + reversed keys for write distribution
   - Bloom filters and caching for read optimization
2. **Cost-Effective Storage**:
   - TTL for automated cleanup
   - Compression for storage efficiency
3. **Scalability**:
   - 100-200 regions per server (10GB default size)
4. **Future-Proofing**:
   - Support for secondary indexes via coprocessors

## Deployment

### Prerequisites
- Docker
- Docker Compose
- Minimum 8GB RAM
- 4 CPU cores

### Starting the Cluster
```bash
docker-compose up -d
```

### Accessing Web Interfaces
- NameNode UI: http://localhost:9871
- Resource Manager: http://localhost:8188
- HBase Master UI: http://localhost:16010
- Region Server UI: http://localhost:16020

### Health Checks
- Master nodes have health checks configured
- Checks NameNode web interface every 30 seconds
- 3 retries with 10-second timeout

## Maintenance

### Logs
- HBase logs are stored in the `hbase-logs` volume
- Data is stored in the `hbase-data` volume

### Scaling
- Region servers can be scaled horizontally
- Resource limits can be adjusted in docker-compose.yaml

### Backup
- Regular backups of the `hbase-data` volume recommended
- Consider using HBase snapshots for point-in-time recovery 
