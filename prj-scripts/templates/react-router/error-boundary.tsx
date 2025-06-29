// 오류 UI 렌더링을 위한 함수
const ErrorBoundaryUI: FC<{
  message: string
  details: string
  stack?: string
}> = ({ message, stack, details }) => {
  return (
    <main className="pt-16 p-4 container mx-auto">
      <h1>{message}</h1>
      <p>{details}</p>
      {stack && (
        <pre className="w-full p-4 overflow-x-auto">
          <code>{stack}</code>
        </pre>
      )}
    </main>
  )
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  // 기본 오류 메시지 설정
  const defaultMessage = 'Oops!'
  const defaultDetails = 'An unexpected error occurred.'

  // 404 오류 처리
  if (isRouteErrorResponse(error) && error.status === 404) {
    return (
      <ErrorBoundaryUI
        message="404"
        details="The requested page could not be found."
      />
    )
  }

  // 기타 라우트 오류 처리
  if (isRouteErrorResponse(error)) {
    return (
      <ErrorBoundaryUI
        message="Error"
        details={error.statusText || defaultDetails}
      />
    )
  }

  // 개발 환경에서의 일반 오류 처리
  if (import.meta.env.DEV && error && error instanceof Error) {
    return (
      <ErrorBoundaryUI
        message={defaultMessage}
        details={error.message}
        stack={error.stack}
      />
    )
  }

  // 기본 오류 UI 반환
  return <ErrorBoundaryUI message={defaultMessage} details={defaultDetails} />
}