export type ButtonVariant = "primary" | "secondary";

export interface ButtonProps {
  variant: ButtonVariant;
  label: string;
  onClick: () => void;
}

export const VARIANT_COLOR_TOKEN: Record<ButtonVariant, string> = {
  primary: "color.primary",
  secondary: "color.surface",
};

export function Button(props: ButtonProps) {
  const token = VARIANT_COLOR_TOKEN[props.variant].replace(".", "-");
  return (
    <button style={{ background: `var(--${token})` }} onClick={props.onClick}>
      {props.label}
    </button>
  );
}
