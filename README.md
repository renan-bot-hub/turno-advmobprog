# Flutter E-Commerce Application

A new Flutter project built for Lab Activity 2.

## Laboratory Discussion

### Lab Activity 2: discussion

In this activity, the application follows a modular design pattern that separates concerns to effectively render data from an API endpoint:

- **Model** (`product.dart`): Defines the data structure. It maps JSON data from the API into strongly-typed Dart objects.
- **Service** (`product_service.dart`): Handles the data fetching logic. It makes the HTTP GET request to the API endpoint, decodes the JSON response, and utilizes the Model's `fromJson` factory to return a list of `Product` objects.
- **Screen** (`product_screen.dart`): Represents the User Interface (View). It relies on a `FutureBuilder` to asynchronously await the data provided by the `ProductService` and dynamically builds the UI components (like the GridView) using the list of `Product` models.

This design pattern improves maintainability, scalability, and code readability by decoupling the UI rendering from the data fetching and parsing logic. Additionally, the Provider package is utilized to handle application-wide state (such as the light/dark theme toggle), ensuring that state management is separate from the UI widget tree.


## Lab Activity 3: discussion
The cart model defines the structure of the data expected from the API. The cart service handles the HTTP request to fetch the cart data by user ID and maps the JSON response to the cart model. The cart screen uses a FutureBuilder to asynchronously fetch and render this data, providing a user interface. When a user clicks on an item, it navigates to the detail_screen, passing the product data to be rendered there.

Design Pattern:
This activity uses the MVC (Model-View-Controller) or Service Repository pattern. The Model (cart.dart) holds data structure. The View (cart_screen.dart, home_screen.dart) handles UI rendering. The Controller/Service (cart_service.dart) handles business logic and API communication.

Using getById at Cart endpoint:
The dummyjson API allows fetching a specific user's cart using the endpoint /carts/user/<id>. By appending the user ID to this endpoint in cart_service.dart, we can easily query and retrieve the specific cart data for any user.
