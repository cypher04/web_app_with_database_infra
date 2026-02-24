# Traffic Flow

## Infrastructure Overview

All resources are deployed in the `rg-webapp-dev` resource group in `West Europe`, within a single Virtual Network `vnet-dev` with address space `10.0.0.0/16`.

### Subnets

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `subnet-dev` (main) | `10.0.1.0/24` | Application Gateway |
| `subnet-db-dev` (database) | `10.0.2.0/24` | Database private endpoint, App Service private endpoint |
| `subnet-app-dev` (app) | `10.0.3.0/24` | App Service VNet integration (delegated to `Microsoft.Web/serverFarms`) |

---

## Inbound Traffic Flow (Internet → App)

```
Internet
  │
  ▼
Static Public IP (pip-dev)
  │
  ▼
Application Gateway (appg-dev) [WAF_v2, subnet: subnet-dev (main)]
  │  - Listens on port 80 (HTTP)
  │  - Frontend IP bound to pip-dev
  │  - WAF Policy (waf-policy-dev) in Prevention mode
  │    - Blocks IPs: 192.168.1.0/24, 10.0.0.0/24
  │    - Blocks requests from 192.168.1.0/24 with "Windows" User-Agent
  │    - OWASP 3.2 managed rule set
  │  - Routes to backend pool via HTTP on port 80
  │
  ▼
Backend Address Pool (appg-backend-pool)
  │
  ▼
Private Endpoint (webapp-pe-appservice-dev) [subnet: subnet-db-dev (database)]
  │  - Connects to Linux Web App via private service connection
  │  - Subresource: "sites"
  │  - DNS: privatelink.azurewebsites.net (linked to vnet-dev)
  │
  ▼
Linux Web App (webappdata-dev) [App Service Plan: asp-dev, SKU: P1v2, OS: Linux]
  │  - Auth enabled (unauthenticated clients redirected to login)
  │  - Client certificate required
  │  - System-assigned managed identity enabled
  │  - Listens on port 3000
```

---

## Outbound Traffic Flow (App → Database)

```
Linux Web App (webappdata-dev)
  │
  │  VNet Integration (azurerm_app_service_virtual_network_swift_connection)
  │  Integrated into subnet-app-dev (app subnet, 10.0.3.0/24)
  │
  ▼
subnet-app-dev → subnet-db-dev (within vnet-dev)
  │
  ▼
Private Endpoint (webapp-pe-database-dev) [subnet: subnet-db-dev (database)]
  │  - Connects to MSSQL Server via private service connection
  │  - Subresource: "sqlServer"
  │  - DNS: privatelink.azurewebsites.net (linked to vnet-dev)
  │
  ▼
MSSQL Server (webapp-mssql-server-dev)
  │  - Version: 12.0
  │  - Public network access: DISABLED
  │  - System-assigned managed identity enabled
  │  - Connection string configured in App Settings:
  │    Server=webapp-sqlserver-dev; Database=webappdbdev; SQL auth
  │
  ▼
MSSQL Database (maindb) [SKU: S0, Max: 2GB, Enclave: VBS]
```

---

## Network Security Rules

### NSG: `nsg-dev` (attached to `subnet-app-dev`, app subnet)

| Rule | Direction | Priority | Access | Protocol | Source Port | Dest Port | Source | Destination |
|------|-----------|----------|--------|----------|-------------|-----------|--------|-------------|
| Allow-HTTP | Inbound | 100 | Allow | TCP | * | 65200-65535 | * | * |
| Allow-HTTPS | Inbound | 110 | Allow | TCP | * | 65200-65535 | * | * |

> Ports 65200-65535 are required for Application Gateway v2 health probes and management.

### NSG: `sg-db-dev` (attached to `subnet-db-dev`, database subnet)

| Rule | Direction | Priority | Access | Protocol | Source Port | Dest Port | Source | Destination |
|------|-----------|----------|--------|----------|-------------|-----------|--------|-------------|
| Allow-DB-Access | Inbound | 100 | Allow | TCP | 3000 | 1433 | 10.0.3.0/24 (app subnet) | * |
| Deny-All-Other | Inbound | 200 | Deny | TCP | * | * | * | * |
| Allow-DB-Outbound | Outbound | 100 | Allow | TCP | * | * | * | * |
| Deny-All-Other-Outbound | Outbound | 200 | Deny | TCP | * | * | * | * |

> Only the app subnet (10.0.3.0/24) can reach port 1433 (SQL) on the database subnet. All other inbound traffic is denied.

---

## Private DNS Resolution

- **Private DNS Zone:** `privatelink.azurewebsites.net`
- **Linked to:** `vnet-dev` (registration disabled)
- **Used by:**
  - App Service private endpoint (`webapp-pe-appservice-dev`) — DNS zone group: `app-dns-zone-group`
  - Database private endpoint (`webapp-pe-database-dev`) — DNS zone group: `db-dns-zone-group`

---

## Identity

- **User-Assigned Managed Identity:** `uai-webappdata-dev` — assigned to the Application Gateway
- **System-Assigned Managed Identity:** Enabled on the Linux Web App and MSSQL Server
