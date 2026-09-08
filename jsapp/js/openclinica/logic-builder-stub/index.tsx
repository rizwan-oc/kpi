/**
 * OC fork — CI-only stand-in for the PRIVATE `@openclinica/logic-builder` package.
 *
 * `@openclinica/logic-builder` is an optionalDependency pinned to a private git
 * ref. The public GitHub Actions CI (fork PRs, no secrets) can't clone it, so
 * it's absent there. This stub is resolved ONLY when the real package isn't
 * installed — see the presence-based fallbacks in `tsconfig.json` (`paths`),
 * `webpack/webpack.common.js` (`resolve.alias`), and `jsapp/jest/unit.config.ts`
 * (`moduleNameMapper`) — so type-check / build / unit tests stay green over all
 * of kpi's own code without the private source.
 *
 * Local dev and the Jenkins/production image install the REAL package and never
 * see this stub (the Dockerfile hard-fails if the real one is missing). The
 * exported TYPES mirror the package's public surface faithfully so kpi's code is
 * still type-checked in CI; the runtime exports are inert — the two components
 * never render and the generate client never reaches the network.
 * Keep in sync with the pinned logic-builder version (0.6.0).
 */
import type { RefObject } from 'react'

export type ExpressionTab = 'calculation' | 'default' | 'constraint' | 'required' | 'relevant' | 'repeatCount'

export interface FormChoice {
  readonly value: string
  readonly label: string
  readonly image?: string
}

interface FormRowBase {
  readonly name: string
  readonly type: string
  readonly label?: string
  readonly hint?: string
  readonly shortDisplayName?: string
  readonly description?: string
  readonly contactDataType?: string
  readonly appearance?: string
  readonly width?: string
  readonly isTarget?: true
}

export interface QuestionRow extends FormRowBase {
  readonly kind: 'question'
  readonly readOnly?: string
  readonly choices?: readonly FormChoice[]
  readonly logic: {
    readonly required?: string
    readonly relevant?: string
    readonly constraint?: string
    readonly constraintMessage?: string
    readonly default?: string
    readonly calculation?: string
    readonly trigger?: string
  }
}

export interface GroupRow extends FormRowBase {
  readonly kind: 'group'
  readonly rows: readonly FormRow[]
  readonly logic: {
    readonly relevant?: string
    readonly repeatCount?: string
  }
}

export type FormRow = QuestionRow | GroupRow

export interface FormContext {
  readonly rows: readonly FormRow[]
}

export interface GenerationRequest {
  readonly prompt: string
  readonly attribute: ExpressionTab
  readonly targetFieldName: string
  readonly form: FormContext
  readonly currentProposal?: string
}

export interface GenerationSuccess {
  readonly kind: 'success'
  readonly expression: string
}

export type FailureReason = 'insufficient_detail' | 'invalid_reference' | 'other_prompt_issue' | 'unavailable'

export interface GenerationFailure {
  readonly kind: 'failure'
  readonly reason: FailureReason
}

export type GenerationResult = GenerationSuccess | GenerationFailure

export interface GenerateClient {
  generate(req: GenerationRequest, opts?: { readonly signal?: AbortSignal }): Promise<GenerationResult>
}

export const ATTRIBUTE_LABELS: Record<ExpressionTab, string> = {
  calculation: 'Calculation',
  default: 'Default Value',
  constraint: 'Constraint Logic',
  required: 'Required Logic',
  relevant: 'Relevant Logic',
  repeatCount: 'Repeat Count',
}

export interface GenerateButtonProps {
  readonly attribute: ExpressionTab
  readonly onOpen: () => void
  readonly disabled?: boolean
}

// Inert stand-in — CI never renders this; the real package supplies the UI.
export function GenerateButton(_props: GenerateButtonProps): JSX.Element | null {
  return null
}

export interface AiGeneratorDialogProps {
  readonly open: boolean
  readonly scope: {
    readonly itemName: string
    readonly attribute: ExpressionTab
    readonly form: FormContext
  }
  readonly client: GenerateClient
  readonly inertRoot?: RefObject<HTMLElement> | HTMLElement | null
  readonly container?: HTMLElement | null
  readonly onApply: (expression: string) => boolean | Promise<boolean>
  // P1.3 AC2 — live editor read driving the inline overwrite confirmation.
  readonly getCurrentExpression: () => string
  readonly onClose: () => void
}

export function AiGeneratorDialog(_props: AiGeneratorDialogProps): JSX.Element | null {
  return null
}

export interface HttpGenerateClientOptions {
  readonly url: string
  readonly getCsrfToken?: () => string | null
  readonly fetchImpl?: typeof fetch
}

// Inert stand-in — CI never calls the network; the real package supplies the client.
export function createHttpGenerateClient(_options: HttpGenerateClientOptions): GenerateClient {
  return {
    generate: async () => ({ kind: 'failure', reason: 'unavailable' }),
  }
}
