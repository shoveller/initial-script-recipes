# 스크립트 레시피

이 저장소는 다양한 자동화 스크립트를 포함하고 있습니다.

## 스크립트 목록

### [n8n-install.sh](./HOW-TO-USE-n8n-install-script.md)
> n8n 설치 자동화 스크립트(aws lightsail 전용)
>   1. 시스템 기본 설정
>       - 관리자 패스워드 설정
>       - 스왑 메모리 설정 (4GB)
>       - 시스템 업데이트
>   2. Docker 환경 구축
>       - Docker 및 Docker Compose 설치
>       - 권한 설정
>   3. 서비스 설치
>       - n8n + PostgreSQL
>       - Nginx Proxy Manager + MySQL
>       - OpenWebUI + PostgreSQL
>   4. S3 백업 시스템 (선택적)
>       - AWS CLI 자동 설치
>       - 자격 증명 설정
>       - S3 버킷 생성
>       - 백업/복원/관리 스크립트 자동 생성
>   5. 관리 스크립트들
>       - 서비스 시작 스크립트
>       - 설정 변경 스크립트들
>       - 백업 관리 스크립트

### [prj.sh](./HOW-TO-USE-prj-script.md)
> 웹 프론트엔드 프로젝트 스케폴드 자동화 스크립트(osx 전용)

자세한 내용은 각 스크립트의 문서를 참고하세요.
