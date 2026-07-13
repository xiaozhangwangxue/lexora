type LexoraWordmarkProps = {
  className?: string;
  hero?: boolean;
};

export function LexoraWordmark({ className = "", hero = false }: LexoraWordmarkProps) {
  return (
    <span
      className={`lexoraWordmark${hero ? " lexoraWordmarkHero" : ""}${className ? ` ${className}` : ""}`}
      aria-label="Lexora"
    >
      <span aria-hidden="true">Le</span>
      <span className="lexoraWordmarkX" aria-hidden="true">x</span>
      <span className="lexoraWordmarkEnd" aria-hidden="true">ora</span>
    </span>
  );
}
