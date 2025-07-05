import * as cdk from 'aws-cdk-lib'
import { Construct } from 'constructs'
import * as lambda from 'aws-cdk-lib/aws-lambda'
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs'
import * as s3 from 'aws-cdk-lib/aws-s3'
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment'
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront'
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins'

type CdkStackProps = cdk.StackProps & {
  // 람다 어댑터의 위치
  lambdaEntry: string
  // 빌드된 static asset 의 위치
  staticAssetPath: string
  // 환경 정보
  environment: string
  // 배포 성공 시 콜백 함수 (Lambda URL 전달)
  onDeploySuccess?: (lambdaUrl: string) => void | Promise<void>
  // DNS 삭제 콜백 함수
  onDestroy?: () => void | Promise<void>
}

export class CdkStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: CdkStackProps) {
    super(scope, id, props)

    // 엔트리포인트에서 람다함수를 참조해서 빌드
    const lambdaFunction = new nodejs.NodejsFunction(this, `${id}-handler`, {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: 'handler',
      entry: props?.lambdaEntry,
      bundling: {
        externalModules: [
          '@aws-sdk/*',
          'aws-sdk' // Not actually needed (or provided): https://github.com/remix-run/react-router/issues/13341
        ],
        minify: true,
        sourceMap: true,
        target: 'es2022'
      },
      environment: {
        NODE_ENV: props?.environment || ''
      }
    })

    // Create Function URL for the Lambda
    const functionUrl = lambdaFunction.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE
    })

    // Create S3 bucket for static assets
    const staticBucket = new s3.Bucket(this, `${id}-s3`, {
      enforceSSL: true,
      publicReadAccess: false,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true
    })

    // Create CloudFront distribution
    const distribution = new cloudfront.Distribution(
      this,
      `${id}-Distribution`,
      {
        defaultBehavior: {
          origin: new origins.FunctionUrlOrigin(functionUrl),
          viewerProtocolPolicy:
            cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
          cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
          originRequestPolicy:
            cloudfront.OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED
        },
        additionalBehaviors: {
          '/assets/*': {
            origin: origins.S3BucketOrigin.withOriginAccessControl(
              staticBucket,
              {
                originAccessLevels: [
                  cloudfront.AccessLevel.READ,
                  cloudfront.AccessLevel.LIST
                ]
              }
            ),
            viewerProtocolPolicy:
              cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
            allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
            cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
            cachePolicy: new cloudfront.CachePolicy(
              this,
              `${id}-StaticCachePolicy`,
              {
                headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
                  'CloudFront-Viewer-Country'
                ),
                queryStringBehavior: cloudfront.CacheQueryStringBehavior.none(),
                cookieBehavior: cloudfront.CacheCookieBehavior.none(),
                defaultTtl: cdk.Duration.days(365),
                maxTtl: cdk.Duration.days(365),
                minTtl: cdk.Duration.days(365)
              }
            )
          }
        }
      }
    )

    // Deploy static assets to S3
    new s3deploy.BucketDeployment(this, `${id}-StaticAssets`, {
      sources: [s3deploy.Source.asset(props?.staticAssetPath || '')],
      destinationBucket: staticBucket,
      destinationKeyPrefix: 'assets',
      distribution,
      distributionPaths: ['/assets/*']
    })

    new cdk.CfnOutput(this, `${id}-DomainName`, {
      value: `https://${distribution.domainName}`,
      description: 'CloudFront Distribution URL'
    })

    // Lambda Function URL을 출력하고 콜백 호출
    new cdk.CfnOutput(this, `${id}-LambdaUrl`, {
      value: functionUrl.url,
      description: 'Lambda Function URL'
    })

    // 배포 성공 시 콜백 호출 (Lambda URL에서 도메인 부분만 추출)
    if (props?.onDeploySuccess) {
      // Lambda URL에서 도메인 부분만 추출 (https:// 제거하고 trailing slash 제거)
      const lambdaDomain = functionUrl.url
        .replace(/^https?:\/\//, '')
        .replace(/\/$/, '')

      // 스택 생성 후 콜백 호출을 위해 nextTick 사용
      process.nextTick(async () => {
        try {
          await props.onDeploySuccess!(lambdaDomain)
        } catch (error) {
          console.error('❌ 배포 후 처리 중 오류 발생:', error)
        }
      })
    }
  }
}