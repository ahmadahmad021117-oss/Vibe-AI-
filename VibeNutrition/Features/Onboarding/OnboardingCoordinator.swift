import SwiftUI

struct OnboardingCoordinator: View {
    @State private var state = OnboardingState.restore()
    let onComplete: (OnboardingState) -> Void

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()

            Group {
                switch state.step {
                case .goal:             GoalScreen(state: state).stepTransition()
                case .currentWeight:    CurrentWeightScreen(state: state).stepTransition()
                case .goalWeight:       GoalWeightScreen(state: state).stepTransition()
                case .pace:             PaceScreen(state: state).stepTransition()
                case .age:              AgeScreen(state: state).stepTransition()
                case .sex:              SexScreen(state: state).stepTransition()
                case .height:           HeightScreen(state: state).stepTransition()
                case .healthSync:       HealthSyncScreen(state: state).stepTransition()
                case .trainingDays:     TrainingDaysScreen(state: state).stepTransition()
                case .mainFocus:        MainFocusScreen(state: state).stepTransition()
                case .mealsPerDay:      MealsPerDayScreen(state: state).stepTransition()
                case .dietaryPref:      DietaryPrefScreen(state: state).stepTransition()
                case .mealSuggestions:  MealSuggestionsScreen(state: state).stepTransition()
                case .notifications:    NotificationsScreen(state: state).stepTransition()
                case .done:             EmptyView()
                }
            }
            .id(state.step) // forces transition between siblings
        }
        .animation(.easeInOut(duration: Theme.Motion.base), value: state.step)
        .onChange(of: state.step) { _, new in
            if new == .done {
                onComplete(state)
            }
        }
    }
}

#Preview {
    // Restores OnboardingState from UserDefaults; in a fresh preview that's
    // an empty state starting at the goal step.
    OnboardingCoordinator { _ in }
        .preferredColorScheme(.dark)
}
