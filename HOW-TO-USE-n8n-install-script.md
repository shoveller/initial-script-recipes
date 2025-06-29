# n8n-install.sh
## 소개
> n8n 설치 자동화 스크립트(aws lightsail 전용)
>   1. 시스템 기본 설정
>       - 관리자 패스워드 설정
>       - 스왑 메모리 설정 (4GB)
>       - 시스템 업데이트
>2. Docker 환경 구축
>   - Docker 및 Docker Compose 설치
>   - 권한 설정
>3. 서비스 설치
>   - n8n + PostgreSQL
>   - Nginx Proxy Manager + MySQL
>   - OpenWebUI + PostgreSQL
>4. S3 백업 시스템 (선택적)
>   - AWS CLI 자동 설치
>   - 자격 증명 설정
>   - S3 버킷 생성
>   - 백업/복원/관리 스크립트 자동 생성
>5. 관리 스크립트들
>   - 서비스 시작 스크립트
>   - 설정 변경 스크립트들
>   - 백업 관리 스크립트

## 실행 흐름

```mermaid
graph TD
    subgraph "초기 설정"
        A[스크립트 시작] --> B{관리자 권한 확인};
        B --> C[관리자 패스워드 설정];
        C --> D[스왑 메모리 설정];
        D --> E[Docker 및 Docker Compose 설치];
    end

    subgraph "서비스 환경 구성"
        E --> F[디렉토리 구조 생성];
        F --> G[환경 변수 설정<br>(n8n 도메인, 암호화 키 등)];
        G --> H[Docker Compose 파일 생성<br>(n8n, npm, openwebui)];
        H --> I[설정 변경 스크립트 생성];
    end

    subgraph "S3 백업 (선택)"
        I --> J{S3 백업 설정 여부?};
        J -- Yes --> K[AWS CLI 설치];
        K --> L[AWS 자격 증명 설정];
        L --> M[S3 버킷 설정];
        M --> N[백업/복원 스크립트 생성];
        N --> O[서비스 시작 스크립트 생성];
        J -- No --> O;
    end

    subgraph "완료"
        O --> P[설치 완료 메시지 출력];
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style J fill:#bbf,stroke:#333,stroke-width:2px
    style P fill:#9f9,stroke:#333,stroke-width:2px
```

## 사용법
> ## 다운로드
> ```shell
> wget https://github.com/shoveller/initial-script-recipes/raw/main/n8n-install.sh
> ```
>
> ## 실행권한 부여
> ```shell
> chmod +x n8n-install.sh
> ```
> 
> ## 설치
> ```shell
> sudo ./n8n-install.sh
> ```
> - 설치 중 S3 백업 설정 여부 선택 가능
> - S3 백업 기능을 설정하시겠습니까? (y/n): y
>
> - 설치 완료 후 생성되는 관리 스크립트들:
> - `./manage-backup.sh`        # 백업 통합 관리
> - `./docker/start-services.sh`  # 서비스 시작

# manage-backup.sh 사용법

## 소개
> S3 백업 기능을 설정하면 만들어지는 스크립트
> === n8n 백업 관리 ===
> 1) 즉시 백업 실행
> 2) S3 백업 목록 확인
> 3) 데이터 복원
> 4) 자동 백업 설정
> 5) 종료
>
> 각 메뉴의 기능:
>
> 1) 즉시 백업 실행
>   - backup-n8n-s3.sh 스크립트를 즉시 실행
>   - n8n_data와 PostgreSQL 데이터를 S3에 백업
>   - 30일 이상 된 백업 파일 자동 정리
>
> 2) S3 백업 목록 확인
>   - S3 버킷의 모든 백업 파일 목록을 표시
>   - 파일 크기와 생성 날짜 포함
>   - n8n-backups/, postgres-backups/ 폴더별로 정리된 목록
>
> 3) 데이터 복원
>   - restore-n8n-s3.sh 스크립트 실행
>   - 사용 가능한 백업 목록 표시
>   - 최신 백업 또는 특정 백업 선택 가능
>   - 기존 데이터 완전 교체 (경고 메시지 포함)
>
> 4) 자동 백업 설정
>   - cron 작업으로 매일 새벽 2시 자동 백업 설정
>   - 0 2 * * * $HOME/backup-n8n-s3.sh >> $HOME/backup.log 2>&1
>   - 백업 로그를 backup.log 파일에 저장
>
> 5) 종료
>   - 스크립트 종료

