import { AssessmentPage } from './AssessmentPage';

@Entry
@Component
struct AssessmentRoutePage {
  build() {
    Column() {
      AssessmentPage()
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
