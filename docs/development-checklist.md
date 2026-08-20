# Development checklist

## Foundation

- [x] Solution and project boundaries
- [x] Docker Compose topology
- [x] SQL Server and database naming
- [x] RabbitMQ service
- [x] Separate Worker container
- [x] Environment-variable configuration
- [x] Identity and EF Core registration
- [x] Central exception middleware
- [x] Pagination primitives
- [x] Flutter mobile/admin source structure
- [x] Shared Flutter API client package

## First implementation slice

- [ ] JWT token service
- [ ] Register endpoint
- [ ] Login endpoint
- [ ] Refresh-token rotation
- [ ] Server-side logout/revocation
- [ ] Current profile endpoint
- [ ] Flutter login form and validation
- [ ] 401 handling and redirect to login

## Before the first feature merge

- [ ] Generate and commit `InitialCreate` migration
- [ ] Change database bootstrap mode to `migrate`
- [ ] Add integration-test project
- [ ] Add CI restore/build/test/analyze workflow
- [ ] Verify the project from a clean clone
