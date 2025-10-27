# Campus Nightlife Map MVP

A Vite + React + TypeScript project with Tailwind CSS and ShadCN UI for building a campus nightlife mapping application.

## Tech Stack

- **Vite** - Fast build tool and dev server
- **React 18** - UI library
- **TypeScript** - Type safety
- **Tailwind CSS** - Utility-first CSS framework
- **ShadCN UI** - Component library
- **ESLint** - Code linting
- **Prettier** - Code formatting

## Getting Started

1. Install dependencies:

   ```bash
   npm install
   ```

2. Start the development server:

   ```bash
   npm run dev
   ```

3. Build for production:
   ```bash
   npm run build
   ```

## Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint
- `npm run lint:fix` - Fix ESLint issues
- `npm run format` - Format code with Prettier
- `npm run format:check` - Check code formatting

## Project Structure

```
src/
├── components/     # Reusable UI components
├── pages/         # Page components
├── styles/        # Global styles and CSS
└── lib/          # Utility functions
```

## Adding ShadCN UI Components

To add new ShadCN UI components, use the CLI:

```bash
npx shadcn-ui@latest add [component-name]
```

Example:

```bash
npx shadcn-ui@latest add button
npx shadcn-ui@latest add card
```
