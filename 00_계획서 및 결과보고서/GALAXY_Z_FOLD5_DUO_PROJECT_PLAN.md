# Galaxy Z Fold5 Duo

> **프로젝트명:** Galaxy Z Fold5 Duo\
> **대상 기기:** Samsung Galaxy Z Fold5\
> **목표:** 폴드를 접고 펼칠 때 내부 화면과 커버 화면이 단순히 끊겨
> 전환되는 것이 아니라, 힌지 각도에 따라 화면이 이동·왜곡·블러되며
> 자연스럽게 이어지는 Duo 스타일 전환 효과를 구현한다.

------------------------------------------------------------------------

## 1. 프로젝트 개요

Galaxy Z Fold5의 기본 화면 전환은 폴드를 완전히 닫는 시점에 내부
디스플레이에서 커버 디스플레이로 전환된다. 이 프로젝트는 이 동작을
확장하여, 접는 과정의 **실제 힌지 각도**를 지속적으로 감지하고 그 값에
따라 화면 전환 애니메이션을 실시간으로 렌더링하는 것을 목표로 한다.

최종적으로는 다음과 같은 경험을 구현한다.

``` text
내부 화면 사용
    ↓
폴드 접기 시작
    ↓
힌지 각도 실시간 감지
    ↓
현재 화면 캡처/프레임 확보
    ↓
각도에 따라 이동 + 원근감 + Blur/Frost 효과
    ↓
커버 화면 방향으로 자연스럽게 이동
    ↓
커버 디스플레이 활성화
    ↓
실제 앱 화면으로 자연스럽게 인계
```

------------------------------------------------------------------------

## 2. 현재까지 확인된 사항

### 2.1 Duo Open

Duo 스타일의 시각적 애니메이션 자체는 구현되어 있다.

-   AGSL/RuntimeShader 기반 화면 변형
-   힌지 각도 기반 애니메이션
-   시뮬레이션 모드에서는 애니메이션 정상 확인
-   Galaxy Z Fold5에서는 실제 접기 동작 시 연속적인 힌지 각도 입력에
    문제가 있음
-   결과적으로 실제 기기에서는 원하는 자연스러운 전환이 발생하지 않음

**판단:** 렌더링/애니메이션 부분의 좋은 참고 구현으로 활용한다.

### 2.2 Folduo

Shizuku를 이용하여 보다 강한 시스템 접근 권한을 확보하는 구조다.

실기기에서 다음 단계까지 확인했다.

-   Wireless Debugging 활성화
-   Shizuku 페어링 성공
-   Shizuku ADB 13.5 실행 성공
-   Folduo의 Shizuku 인증 성공
-   Fold5에서는 완전히 접힌 이후에야 커버 화면이 활성화되는 현상 확인

현재 Folduo 구현은 Fold7 SM-F966Z 중심의 실험적 구현이므로 Fold5에서
그대로 사용하는 것을 최종 해결책으로 삼지 않는다.

**판단:** Shizuku 권한 처리와 디스플레이 제어 방식의 참고 자료로
활용한다.

### 2.3 ZFoldDuo

가장 우선적으로 분석할 프로젝트다.

주목할 부분:

-   Samsung 내부 힌지 각도 접근 방식
-   Wireless Debugging / 내부 ADB 활용
-   힌지 각도 스트림 처리
-   Duo 스타일 화면 전환
-   AGSL 기반 공간 변형 효과

**핵심 검증 과제:** Galaxy Z Fold5에서 삼성 내부 힌지 값을 연속적으로
얻을 수 있는가?

------------------------------------------------------------------------

## 3. 핵심 기술 과제

이 프로젝트의 가장 중요한 문제는 애니메이션 자체가 아니다.

### 핵심 1. Fold5의 연속 힌지 각도 확보

목표 값:

``` text
180°
170°
160°
150°
...
90°
...
30°
20°
10°
0°
```

이와 같은 연속적 또는 충분히 세밀한 각도 데이터가 필요하다.

표준 Android `TYPE_HINGE_ANGLE`이 Fold5에서 충분한 값을 제공하지 않는
경우 삼성 내부 센서를 조사한다.

조사 후보:

``` text
TYPE_HINGE_ANGLE
FOLDING_ANGLE_NON_WAKEUP
lid_angle_fusion_Wakeup
folding_state_lpm_Wakeup
Samsung vendor/internal sensor
```

필요하면 ADB/Shizuku를 이용한 접근도 검토한다.

### 핵심 2. 내부/커버 디스플레이 제어

기본 One UI 동작에만 의존하면 완전히 접히기 전까지 커버 화면으로
전환되지 않는다.

따라서 다음을 조사한다.

``` text
DisplayManager
Samsung internal display API
ADB display commands
Shizuku privileged API
SurfaceControl
VirtualDisplay
Accessibility
Samsung system service
```

목표는 실제 디스플레이 전환 시점과 애니메이션 시점을 최대한 자연스럽게
연결하는 것이다.

### 핵심 3. 화면 연속성

전환 도중 실제 앱이 갑자기 사라지지 않도록 현재 화면을 임시
이미지/프레임으로 유지한다.

개념:

``` text
현재 앱
 ↓
화면 프레임 확보
 ↓
임시 Transition Surface
 ↓
힌지 각도 기반 변형
 ↓
대상 디스플레이 준비
 ↓
실제 앱 화면으로 교체
```

보호된 콘텐츠와 DRM 화면은 캡처 대상에서 제외한다.

### 핵심 4. Duo 스타일 렌더링

힌지 각도를 다음 그래픽 파라미터로 변환한다.

-   Perspective
-   Parallax
-   Scale
-   Translation
-   Blur
-   Frosted glass
-   Darkening
-   Edge deformation

가능하면 GPU에서 처리한다.

우선 검토:

``` text
AGSL
RuntimeShader
RenderEffect
SurfaceControl
Hardware accelerated Canvas
```

------------------------------------------------------------------------

## 4. 목표 아키텍처

``` text
┌──────────────────────────────┐
│       Galaxy Z Fold5         │
└──────────────┬───────────────┘
               │
        Hinge Angle Source
               │
     ┌─────────▼─────────┐
     │ Fold5 Angle Engine│
     │ Samsung / ADB     │
     └─────────┬─────────┘
               │
          angle 0~180°
               │
     ┌─────────▼─────────┐
     │ Transition Engine │
     └──────┬───────┬────┘
            │       │
     Screen Frame   Display State
            │       │
     ┌──────▼───────▼────┐
     │   AGSL Renderer    │
     │ Perspective/Blur   │
     └─────────┬─────────┘
               │
     ┌─────────▼─────────┐
     │ Display Handover  │
     └──────┬───────┬────┘
            │       │
       Inner OLED  Cover OLED
```

------------------------------------------------------------------------

## 5. 개발 단계

### Phase 1. Fold5 센서 조사

**목표:** 실제 Fold5에서 연속 힌지 각도를 얻는다.

작업:

1.  Android SensorManager 센서 전체 목록 출력
2.  힌지 관련 Samsung vendor sensor 식별
3.  접힘/펼침 과정의 raw value 기록
4.  표준 `TYPE_HINGE_ANGLE`과 비교
5.  ADB에서 접근 가능한 삼성 내부 데이터 조사
6.  ZFoldDuo의 angle source 분석
7.  0\~180° 연속 데이터 확보 여부 판정

**완료 조건:** Fold5를 천천히 접었을 때 앱 로그에서 각도가 연속적으로
변화한다.

------------------------------------------------------------------------

### Phase 2. ZFoldDuo Fold5 실기기 테스트

**목표:** 기존 구현을 최소 수정으로 Fold5에서 시험한다.

작업:

1.  ZFoldDuo 소스 확보
2.  Android Studio 빌드 환경 구성
3.  모델 제한 코드 확인
4.  Fold5 `SM-F946` 계열 모델 처리
5.  Wireless Debugging 연결
6.  Accessibility 권한 설정
7.  Samsung internal hinge angle 테스트
8.  로그 저장

**완료 조건:** Fold5 실제 접기 동작으로 ZFoldDuo 내부 angle 값이
변화한다.

------------------------------------------------------------------------

### Phase 3. Fold5 Angle Engine 제작

ZFoldDuo 방식이 성공하면 해당 구조를 독립 모듈화한다.

예상 구조:

``` text
angle/
 ├─ HingeAngleSource.kt
 ├─ SamsungAngleSource.kt
 ├─ StandardAngleSource.kt
 ├─ AdbAngleSource.kt
 └─ AngleRuntime.kt
```

우선순위:

``` text
Samsung Internal
      ↓ 실패
Standard Hinge Sensor
      ↓ 실패
ADB Helper
```

------------------------------------------------------------------------

### Phase 4. Duo Open 렌더러 결합

Duo Open에서 참고할 부분:

-   AGSL shader
-   화면 원근 변형
-   Blur/Frost
-   좌우 이동
-   hinge-angle interpolation

새 구조:

``` text
Fold5 Angle Engine
        +
Duo-style AGSL Renderer
        +
Display Control Layer
```

------------------------------------------------------------------------

### Phase 5. 화면 캡처 및 Transition Surface

현재 앱 화면을 전환 순간 임시 프레임으로 확보한다.

요구사항:

-   메모리에서만 처리
-   파일 저장 금지
-   전환 완료 즉시 폐기
-   보호된 화면 제외
-   지연 최소화

목표:

``` text
Capture latency < 1 frame 수준을 지향
Animation 60 FPS 이상 지향
```

실기기 성능에 따라 목표값을 조정한다.

------------------------------------------------------------------------

### Phase 6. Display Handover

가장 난도가 높은 단계다.

목표:

``` text
Inner Display
      ↓
Transition animation
      ↓
Cover Display 준비
      ↓
실제 앱 표시
```

조사 순서:

1.  Android 공개 API
2.  Accessibility 기반 제어
3.  Shizuku
4.  ADB privileged command
5.  Samsung internal API
6.  SurfaceControl 계열 접근

시스템 안정성을 해치는 강제 제어는 마지막 수단으로 둔다.

------------------------------------------------------------------------

### Phase 7. UX 튜닝

기본 목표 애니메이션:

``` text
180°  내부 화면 정상
150°  약한 perspective
120°  이동 시작
 90°  parallax + blur 증가
 60°  커버 방향 이동 강화
 30°  커버 화면 handover 준비
  0°  커버 화면 완전 전환
```

각도는 실제 Fold5 센서 특성에 따라 재조정한다.

사용자 조절 항목 후보:

-   Animation strength
-   Perspective
-   Blur
-   Frost
-   Darkening
-   Eye distance
-   Transition threshold
-   Animation direction
-   Cover handover angle

------------------------------------------------------------------------

## 6. 앱 구조 제안

``` text
GalaxyZFold5Duo/
│
├─ app/
│
├─ angle/
│   ├─ standard/
│   ├─ samsung/
│   └─ adb/
│
├─ display/
│   ├─ DisplayController
│   └─ DisplayHandover
│
├─ capture/
│   └─ ScreenFrameProvider
│
├─ renderer/
│   ├─ DuoRenderer
│   └─ shaders/
│       └─ spatial_projection.agsl
│
├─ service/
│   └─ FoldTransitionService
│
├─ ui/
│   ├─ MainActivity
│   └─ DiagnosticsActivity
│
└─ docs/
    ├─ SENSOR_TEST.md
    ├─ FOLD5_NOTES.md
    └─ TEST_RESULTS.md
```

------------------------------------------------------------------------

## 7. 진단 화면

개발 초기에는 화려한 UI보다 진단 기능을 우선한다.

표시 항목:

``` text
Device       : Galaxy Z Fold5
Model        : SM-F946...
Hinge source : Samsung Internal
Hinge angle  : 117.4°
Fold state   : HALF_OPENED

Inner display: ON
Cover display: ON/OFF

Shizuku      : Connected
ADB          : Connected
Accessibility: Enabled

FPS          : 60
Frame latency: xx ms
```

그리고 **Record Sensor Log** 버튼을 두어 실제 접기 테스트 결과를
저장한다.

------------------------------------------------------------------------

## 8. 성공 판정 기준

### Level 1

Fold5에서 실제 힌지 각도를 연속적으로 읽는다.

### Level 2

힌지 각도에 따라 테스트 화면이 실시간으로 변형된다.

### Level 3

현재 앱 화면을 대상으로 동일한 애니메이션을 적용한다.

### Level 4

내부 화면과 커버 화면 사이의 handover를 애니메이션과 연결한다.

### Level 5

일상적으로 사용할 수 있을 정도의 안정성을 확보한다.

``` text
60 FPS급 애니메이션
낮은 전환 지연
앱 강제 종료 최소화
잠금/해제 정상
전화 수신 정상
AOD 정상
멀티태스킹 정상
재부팅 후 복구 가능
```

------------------------------------------------------------------------

## 9. 개발 우선순위

가장 중요한 원칙은 **애니메이션부터 만들지 않는 것**이다.

``` text
① Fold5 연속 힌지 각도 확보
          ↓
② 각도값으로 테스트 그래픽 움직이기
          ↓
③ 실제 화면 프레임 적용
          ↓
④ 내부/커버 디스플레이 제어
          ↓
⑤ Duo 스타일 효과 고도화
          ↓
⑥ 안정화
```

**Phase 1이 실패하면 Phase 2 이후 구조를 재검토한다.**

------------------------------------------------------------------------

## 10. 참고 프로젝트

### Duo Open

GitHub:

https://github.com/marcoazeem/duo-open

주요 참고 대상:

-   AGSL animation
-   RuntimeShader
-   HingeAngleSource
-   Duo-style visual transition

### ZFoldDuo

GitHub:

https://github.com/nnnnnnn0090/Z-Fold-Duo-TEST

주요 참고 대상:

-   Samsung internal hinge angle
-   Embedded ADB
-   AngleRuntime
-   Galaxy Fold display handling
-   AGSL spatial projection

### Folduo

GitHub:

https://github.com/bunkaich/Folduo

주요 참고 대상:

-   Shizuku
-   Display control
-   Screen capture
-   Transition architecture
-   Fold-series experimental implementation

------------------------------------------------------------------------

## 11. 첫 번째 개발 세션 실행 프롬프트

Codex/Claude Code 등 코딩 에이전트에서 프로젝트를 시작할 때 다음
프롬프트를 사용한다.

``` text
첨부한 GALAXY_Z_FOLD5_DUO_PROJECT_PLAN.md를 처음부터 끝까지 읽고
이 문서를 프로젝트의 개발 계획과 우선순위로 사용하세요.

프로젝트명:
Galaxy Z Fold5 Duo

대상 기기:
Samsung Galaxy Z Fold5

최종 목표:
Galaxy Z Fold5를 접거나 펼칠 때 현재 화면이 끊겨 전환되는 대신,
실제 힌지 각도에 따라 화면이 이동, 원근 변형, blur/frost 효과를 거치며
내부 디스플레이와 커버 디스플레이 사이를 자연스럽게 이어주는
Duo 스타일 전환 애니메이션을 구현합니다.

참고 프로젝트:
1. https://github.com/marcoazeem/duo-open
2. https://github.com/nnnnnnn0090/Z-Fold-Duo-TEST
3. https://github.com/bunkaich/Folduo

중요:
바로 전체 앱을 구현하지 마세요.

첫 번째 목표는 오직 Galaxy Z Fold5에서
연속적인 실제 힌지 각도를 얻을 수 있는 방법을 검증하는 것입니다.

먼저 다음 작업만 수행하세요.

1. 참고 프로젝트의 힌지 각도 획득 코드를 분석합니다.
2. Android 표준 TYPE_HINGE_ANGLE과 Samsung internal/vendor sensor 방식을 비교합니다.
3. ZFoldDuo의 Samsung internal hinge angle 및 embedded ADB 구조를 분석합니다.
4. Fold5에서 사용할 수 있는 후보 방식을 정리합니다.
5. 가장 작은 Sensor Diagnostic APK를 설계합니다.
6. 실제 Fold5에서 0~180도의 연속적인 각도값을 얻는 테스트 방법을 작성합니다.

추측으로 Fold5 호환성을 단정하지 마세요.
실기기 로그를 기준으로 다음 단계 진행 여부를 판단하세요.

기존 오픈소스 코드를 사용할 경우 라이선스와 저작권 고지를 확인하고,
그 결과를 문서에 기록하세요.

분석 결과와 구현 계획을 먼저 제시하고,
내 승인 전에는 대규모 리팩터링이나 전체 앱 구현으로 넘어가지 마세요.
```

------------------------------------------------------------------------

## 12. 프로젝트의 첫 번째 체크포인트

첫 번째 체크포인트는 단 하나다.

> **Galaxy Z Fold5에서 실제 힌지 각도를 연속적으로 얻을 수 있는가?**

성공 예:

``` text
[HINGE] 178.2
[HINGE] 173.7
[HINGE] 165.1
[HINGE] 151.8
[HINGE] 137.4
[HINGE] 119.6
[HINGE] 101.3
[HINGE]  82.1
[HINGE]  61.7
[HINGE]  42.5
[HINGE]  21.4
[HINGE]   5.2
```

이 단계가 성공하면 **Galaxy Z Fold5 Duo의 핵심 기술적 장애물 하나가
해결된 것**으로 판단하고 렌더링 및 디스플레이 handover 단계로 진행한다.

------------------------------------------------------------------------

**문서 버전:** v1.0\
**작성일:** 2026-09-17
