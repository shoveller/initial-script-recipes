1. setup-aws-cli.sh - AWS CLI 설치 및 설정
2. backup-n8n-s3.sh - n8n 데이터 S3 백업
3. setup-backup-cron.sh - 자동 백업 cron 설정
4. restore-n8n-s3.sh - S3에서 데이터 복원

사용 방법:

# 1. AWS CLI 설치 및 설정
```shell
sudo ./setup-aws-cli.sh
```

# 2. 수동 백업 실행
```shell
./backup-n8n-s3.sh
```

# 3. 자동 백업 설정 (cron)
```shell
./setup-backup-cron.sh
```

# 4. 복원 (필요시)
```shell
./restore-n8n-s3.sh
```

백업되는 데이터:

- n8n_data: 워크플로우, 설정, 자격증명 등
- postgres_data: PostgreSQL 데이터베이스 덤프
- Docker 볼륨: 추가 볼륨 데이터

주요 기능:

- S3 버킷 자동 생성
- 30일 이상 된 백업 자동 정리
- 이메일 알림 (선택사항)
- 백업 관리 스크립트 포함
- 복원 전 현재 데이터 백업
- 로그 로테이션 설정
