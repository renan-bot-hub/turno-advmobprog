# Flutter E-Commerce Application

A new Flutter project built for Lab Activity 2.

## Laboratory Discussion

### Lab Activity 2: discussion

In this activity, the application follows a modular design pattern that separates concerns to effectively render data from an API endpoint:

- **Model** (`product.dart`): Defines the data structure. It maps JSON data from the API into strongly-typed Dart objects.
- **Service** (`product_service.dart`): Handles the data fetching logic. It makes the HTTP GET request to the API endpoint, decodes the JSON response, and utilizes the Model's `fromJson` factory to return a list of `Product` objects.
- **Screen** (`product_screen.dart`): Represents the User Interface (View). It relies on a `FutureBuilder` to asynchronously await the data provided by the `ProductService` and dynamically builds the UI components (like the GridView) using the list of `Product` models.

This design pattern improves maintainability, scalability, and code readability by decoupling the UI rendering from the data fetching and parsing logic. Additionally, the Provider package is utilized to handle application-wide state (such as the light/dark theme toggle), ensuring that state management is separate from the UI widget tree.
